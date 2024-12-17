require 'rack/utils'
module ForemanOpenscap
  class Policy < ApplicationRecord
    audited
    include Authorizable
    include Taxonomix
    include PolicyCommon

    attr_writer :current_step, :wizard_initiated

    STEPS_LIST = [N_('Deployment Options'), N_('Policy Attributes'), N_('SCAP Content'), N_('Schedule'), N_('Locations'), N_('Organizations'), N_('Hostgroups')]

    belongs_to :scap_content
    belongs_to :scap_content_profile
    belongs_to :tailoring_file
    belongs_to :tailoring_file_profile, :class_name => 'ForemanOpenscap::ScapContentProfile'
    has_many :policy_arf_reports
    has_many :arf_reports, :through => :policy_arf_reports, :dependent => :destroy
    has_many :asset_policies
    has_many :assets, :through => :asset_policies, :as => :assetable, :dependent => :destroy

    scoped_search :on => :name, :complete_value => true
    scoped_search :relation => :scap_content, :on => :title, :rename => 'content', :complete_value => true
    scoped_search :relation => :scap_content_profile, :on => :title, :rename => 'profile', :complete_value => true
    scoped_search :relation => :tailoring_file, :on => :name, :rename => 'tailoring_file', :complete_value => true
    scoped_search :relation => :tailoring_file_profile, :on => :title, :rename => 'tailoring_file_profile', :complete_value => true

    def self.deploy_by_variants
      %w[puppet ansible manual]
    end

    validates :name, :presence => true, :uniqueness => true, :length => { :maximum => 255 },
                     :if => Proc.new { |policy| policy.should_validate?('Policy Attributes') }
    validates :treshold, :presence => true, :if => Proc.new { |policy| policy.should_validate?('Policy Attributes') }

    validates :period, :inclusion => { :in => %w[weekly monthly custom], :message => _('is not a valid value') },
                       :if => Proc.new { |policy| policy.should_validate?('Schedule') }
    validates :deploy_by, :inclusion => { :in => Policy.deploy_by_variants },
                          :if => Proc.new { |policy| policy.should_validate?('Deployment Options') }

    validates :scap_content_id, presence: true, if: Proc.new { |policy| policy.should_validate?('SCAP Content') }
    validate :matching_content_profile, if: Proc.new { |policy| policy.should_validate?('SCAP Content') }

    validate :valid_tailoring, :valid_tailoring_profile, :no_mixed_deployments, :treshold_value
    validate :valid_cron_line, :valid_weekday, :valid_day_of_month, :if => Proc.new { |policy| policy.should_validate?('Schedule') }
    after_save :assign_policy_to_hostgroups
    after_save :refresh_compliance_status
    # before_destroy - ensure that the policy has no hostgroups, or classes

    default_scope do
      with_taxonomy_scope do
        order("foreman_openscap_policies.name")
      end
    end

    def to_html
      if scap_content.nil?
        return html_error_message(_('Cannot generate HTML guide, scap content is missing.'))
      end

      if (proxy = scap_content.proxy_url)
        api = ProxyAPI::Openscap.new(:url => proxy)
      else
        return html_error_message(_('Cannot generate HTML guide, no valid OpenSCAP proxy server found.'))
      end

      api.policy_html_guide(scap_content.scap_file, scap_content_profile.try(:profile_id))
    end

    def change_deploy_type(params)
      self.class.transaction do
        if params[:deploy_by] && deploy_by != params[:deploy_by]
          assign_attributes params
          ForemanOpenscap::LookupKeyOverrider.new(self).override
        end

        errors.none? && update(params)
      end
    end

    def hostgroup_ids
      assets.where(:assetable_type => 'Hostgroup').pluck(:assetable_id)
    end

    def hostgroup_ids=(ids)
      assign_ids ids, 'Hostgroup'
    end

    def hostgroups
      ::Hostgroup.find(hostgroup_ids)
    end

    def hostgroups=(hostgroups)
      hostgroup_ids = hostgroups.map(&:id).map(&:to_s)
    end

    def host_ids
      assets.where(:assetable_type => 'Host::Base').pluck(:assetable_id)
    end

    def host_ids=(ids)
      assign_ids ids, 'Host::Base'
    end

    def hosts
      ::Host.where(:id => host_ids)
    end

    def hosts=(hosts)
      host_ids = hosts.map(&:id).map(&:to_s)
    end

    def all_hosts
      hg_ids = hostgroups.flat_map(&:subtree_ids).uniq
      (Host.where(:hostgroup_id => hg_ids) + hosts).uniq
    end

    def refresh_host_statuses
      all_hosts.map do |host|
        host.refresh_statuses([HostStatus.find_status_by_humanized_name("compliance")])
      end
    end

    def step_to_i(step_name)
      steps.index(step_name) + 1
    end

    def steps
      STEPS_LIST
    end

    def current_step
      @current_step || steps.first
    end

    def previous_step
      return steps.last if current_step.empty?
      steps[steps.index(current_step) - 1]
    end

    def next_step
      steps[steps.index(current_step) + 1]
    end

    def rewind_step
      @current_step = previous_step
    end

    def first_step?
      current_step == steps.first
    end

    def current_step?(step_name)
      current_step == step_name
    end

    def last_step?
      current_step == steps.last
    end

    def wizard_completed?
      new_record? && current_step.blank?
    end

    def step_index
      wizard_completed? ? steps.index(steps.last) : steps.index(current_step) + 1
    end

    def scan_name
      name
    end

    def used_location_ids
      Location.joins(:taxable_taxonomies).where(
        'taxable_taxonomies.taxable_type' => 'ForemanOpenscap::Policy',
        'taxable_taxonomies.taxable_id'   => id
      ).pluck("#{Location.arel_table.name}.id")
    end

    def used_organization_ids
      Organization.joins(:taxable_taxonomies).where(
        'taxable_taxonomies.taxable_type' => 'ForemanOpenscap::Policy',
        'taxable_taxonomies.taxable_id'   => id
      ).pluck("#{Location.arel_table.name}.id")
    end

    def used_hostgroup_ids
      []
    end

    def unassign_hosts(hosts)
      policy_host_assets = ForemanOpenscap::Asset.joins(:asset_policies).where(
        :assetable_type => 'Host::Base',
        :assetable_id => hosts.map(&:id),
        :foreman_openscap_asset_policies => { :policy_id => id }
      ).pluck(:id)

      self.asset_ids = self.asset_ids - policy_host_assets
      ForemanOpenscap::Asset.where(:id => policy_host_assets).destroy_all
    end

    def to_enc
      {
        'id'            => self.id,
        'profile_id'    => profile_for_scan,
        'content_path'  => "/var/lib/openscap/content/#{self.scap_content.digest}.xml",
        'tailoring_path' => tailoring_file ? "/var/lib/openscap/tailoring/#{self.tailoring_file.digest}.xml" : '',
        'download_path' => "/compliance/policies/#{self.id}/content/#{scap_content.digest}",
        'tailoring_download_path' => tailoring_file ? "/compliance/policies/#{self.id}/tailoring/#{tailoring_file.digest}" : ''
      }.merge(period_enc)
    end

    def should_validate?(step_name)
      if new_record? && wizard_initiated?
        step_index > step_to_i(step_name)
      elsif new_record? && !wizard_initiated?
        true
      else
        persisted?
      end
    end

    def wizard_initiated?
      @wizard_initiated
    end

    private

    def html_error_message(message)
      error_message = '<div class="alert alert-danger"><span class="pficon pficon-error-circle-o"></span><strong>' <<
        message <<
        '</strong></div>'
      error_message.html_safe
    end

    def valid_tailoring
      errors.add(:tailoring_file_id, _("must be present when tailoring file profile present")) if tailoring_file_profile_id && !tailoring_file_id
      errors.add(:tailoring_file_profile_id, _("must be present when tailoring file present")) if !tailoring_file_profile_id && tailoring_file_id
    end

    def valid_tailoring_profile
      if tailoring_file && tailoring_file_profile && !ScapContentProfile.where(:tailoring_file_id => tailoring_file_id).include?(tailoring_file_profile)
        errors.add(:tailoring_file_profile, _("does not come from selected tailoring file"))
      end
    end

    def matching_content_profile
      if scap_content_id && scap_content_profile_id && !ScapContent.find(scap_content_id).scap_content_profile_ids.include?(scap_content_profile_id)
        errors.add(:scap_content_id, _("does not have the selected SCAP content profile"))
      end
    end

    def assign_policy_to_hostgroups
      HostgroupOverrider.new(self).populate
    end

    def profile_for_scan
      if tailoring_file_profile
        tailoring_file_profile.profile_id
      elsif scap_content_profile
        scap_content_profile.profile_id
      else
        ''
      end
    end

    def assign_ids(ids, class_name)
      new_assets = ids.uniq.reject { |id| id.respond_to?(:empty?) && id.empty? }.reduce([]) do |memo, id|
        memo << assets.where(:assetable_type => class_name, :assetable_id => id).first_or_initialize
      end
      complimentary_class_name = class_name == 'Host::Base' ? 'Hostgroup' : 'Host::Base'
      existing_assets = self.assets.select { |assigned_asset| assigned_asset.assetable_type == complimentary_class_name }
      self.assets = existing_assets + new_assets
    end

    def no_mixed_deployments
      assets.each do |asset|
        assetable = asset.assetable
        next unless assetable
        unless assetable.policies.where.not(:id => id).pluck(:deploy_by).all? { |deployed_by| deployed_by == deploy_by }
          errors.add(:base, _("cannot assign to %s, all assigned policies must be deployed in the same way, check 'deploy by' for each assigned policy") % assetable.name)
        end
      end
    end

    def treshold_value
      if (100 < treshold || treshold < 0) && should_validate?('Policy Attributes')
        errors.add(:treshold, _("must be between 0 and 100"))
      end
    end

    def refresh_compliance_status
      return if id_previously_changed?
      refresh_host_statuses
    end
  end
end

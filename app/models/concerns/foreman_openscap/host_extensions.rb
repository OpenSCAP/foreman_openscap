module ForemanOpenscap
  module HostExtensions
    extend ActiveSupport::Concern
    ::Host::Managed::Jail.allow :policies_enc

    included do
      has_one :asset, :as => :assetable, :class_name => "::ForemanOpenscap::Asset"
      has_many :asset_policies, :through => :asset, :class_name => "::ForemanOpenscap::AssetPolicy"
      has_many :policies, :through => :asset_policies, :class_name => "::ForemanOpenscap::Policy"
      has_many :arf_reports, :class_name => '::ForemanOpenscap::ArfReport', :foreign_key => :host_id
      has_one :compliance_status_object, :class_name => '::ForemanOpenscap::ComplianceStatus', :foreign_key => 'host_id'

      scoped_search :relation => :policies, :on => :name, :complete_value => true, :rename => :compliance_policy,
                    :only_explicit => true, :operators => ['= '], :ext_method => :search_by_policy_name

      scoped_search :relation => :policies, :on => :name, :complete_value => true, :rename => :compliance_report_missing_for,
                    :only_explicit => true, :operators => ['= ', '!= '], :ext_method => :search_by_missing_arf

      scoped_search :relation => :compliance_status_object, :on => :status, :rename => :compliance_status,
                    :complete_value => { :compliant => ::ForemanOpenscap::ComplianceStatus::COMPLIANT,
                                         :incompliant => ::ForemanOpenscap::ComplianceStatus::INCOMPLIANT,
                                         :inconclusive => ::ForemanOpenscap::ComplianceStatus::INCONCLUSIVE }
      after_update :puppetrun!, :if => ->(host) { Setting[:puppetrun] && host.changed.include?('openscap_proxy_id') }

      scope :comply_with, lambda { |policy|
        joins(:arf_reports).merge(ArfReport.latest_of_policy(policy)).merge(ArfReport.passed)
      }

      scope :incomply_with, lambda { |policy|
        joins(:arf_reports).merge(ArfReport.latest_of_policy(policy)).merge(ArfReport.failed)
      }

      scope :inconclusive_with, lambda { |policy|
        joins(:arf_reports).merge(ArfReport.latest_of_policy(policy)).merge(ArfReport.othered)
      }

      scope :policy_reports_missing, lambda { |policy|
        search_for("compliance_report_missing_for = \"#{policy.name}\"")
      }

      scope :assigned_to_policy, lambda { |policy|
        search_for("compliance_policy = \"#{policy.name}\"")
      }

      alias_method_chain :inherited_attributes, :openscap
    end

    def inherited_attributes_with_openscap
      inherited_attributes_without_openscap.concat(%w[openscap_proxy_id])
    end

    def policies=(policies)
      self.create_asset(:assetable => self) if self.asset.blank?
      self.asset.policies = policies
    end

    def get_asset
      ForemanOpenscap::Asset.where(:assetable_type => 'Host::Base', :assetable_id => id).first_or_create!
    end

    def policies_enc
      check = ForemanOpenscap::OpenscapProxyAssignedVersionCheck.new(self).run
      method = check.pass? ? :to_enc : :to_enc_legacy
      combined_policies.map(&method).to_json
    end

    def combined_policies
      combined = self.hostgroup ? self.policies + self.hostgroup.policies + self.hostgroup.inherited_policies : self.policies
      combined.uniq
    end

    def scap_status_changed?(policy)
      last_reports = reports_for_policy(policy, 2)
      return false if last_reports.length != 2
      !last_reports.first.equal? last_reports.last
    end

    def last_report_for_policy(policy)
      reports_for_policy(policy, 1)
    end

    def reports_for_policy(policy, limit = nil)
      if limit
        ForemanOpenscap::ArfReport.joins(:policy_arf_report)
                                  .merge(ForemanOpenscap::PolicyArfReport.of_policy(policy.id)).where(:host_id => id).limit limit
      else
        ForemanOpenscap::ArfReport.joins(:policy_arf_report)
                                  .merge(ForemanOpenscap::PolicyArfReport.of_policy(policy.id)).where(:host_id => id)
      end
    end

    def compliance_status(options = {})
      @compliance_status ||= get_status(ForemanOpenscap::ComplianceStatus).to_status(options)
    end

    def compliance_status_label(options = {})
      @compliance_status_label ||= get_status(ForemanOpenscap::ComplianceStatus).to_label(options)
    end

    module ClassMethods
      def search_by_policy_name(key, operator, policy_name)
        cond = sanitize_sql_for_conditions(["foreman_openscap_policies.name #{operator} ?", value_to_sql(operator, policy_name)])

        host_group_host_ids = policy_assigned_using_hostgroup_host_ids cond, []
        host_group_cond = if host_group_host_ids.any?
                            ' OR ' + sanitize_sql_for_conditions("hosts.id IN (#{host_group_host_ids.join(',')})")
                          else
                            ''
                          end
        { :conditions => Host::Managed.arel_table[:id].in(Host::Managed.select(Host::Managed.arel_table[:id]).joins(:policies).where(cond).pluck(:id)).to_sql + host_group_cond }
      end

      def search_by_missing_arf(key, operator, policy_name)
        cond = sanitize_sql_for_conditions(["foreman_openscap_policies.name #{operator} ?", value_to_sql(operator, policy_name)])

        host_ids_from_arf_of_policy = ForemanOpenscap::ArfReport.joins(:policy).where(cond).pluck(:host_id).uniq

        direct_result = policy_assigned_directly_host_ids cond, host_ids_from_arf_of_policy

        hg_result = policy_assigned_using_hostgroup_host_ids cond, host_ids_from_arf_of_policy

        result = (direct_result + hg_result).uniq
        { :conditions => "hosts.id IN (#{result.empty? ? 'NULL' : result.join(',')})" }
      end

      def policy_assigned_directly_host_ids(condition, host_ids_from_arf)
        ForemanOpenscap::Asset.where(:assetable_type => 'Host::Base')
                              .joins(:policies)
                              .where(condition)
                              .where.not(:assetable_id => host_ids_from_arf)
                              .pluck(:assetable_id)
      end

      def policy_assigned_using_hostgroup_host_ids(condition, host_ids_from_arf)
        hostgroup_with_policy_ids = ForemanOpenscap::Asset.where(:assetable_type => 'Hostgroup')
                                                          .joins(:policies)
                                                          .where(condition)
                                                          .pluck(:assetable_id)
        subtree_ids = Hostgroup.where(:id => hostgroup_with_policy_ids).flat_map(&:subtree_ids).uniq
        Host.where(:hostgroup_id => subtree_ids).where.not(:id => host_ids_from_arf).pluck(:id)
      end
    end
  end
end

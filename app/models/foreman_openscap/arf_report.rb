require 'foreman_openscap/helper'

module ForemanOpenscap
  class ArfReport < ::Report
    include Taxonomix
    include OpenscapProxyExtensions

    # attr_accessible :host_id, :reported_at, :status, :metrics
    METRIC = %w[passed othered failed].freeze
    BIT_NUM = 10
    MAX = (1 << BIT_NUM) - 1

    include ComplianceStatusScopedSearch

    scoped_search :on => :status, :offset => 0, :word_size => 4 * BIT_NUM, :complete_value => { :true => true, :false => false }, :rename => :eventful

    has_one :policy_arf_report
    has_one :policy, :through => :policy_arf_report, :dependent => :destroy
    has_one :asset, :through => :host, :class_name => 'ForemanOpenscap::Asset', :as => :assetable
    has_one :log, :foreign_key => :report_id
    belongs_to :openscap_proxy, :class_name => "SmartProxy"

    after_save :assign_locations_organizations
    before_destroy :destroy_from_proxy

    delegate :asset=, :to => :host

    default_scope do
      with_taxonomy_scope do
        order("#{self.table_name}.created_at DESC")
      end
    end

    scope :hosts, lambda { includes(:policy) }
    scope :of_policy, lambda { |policy_id| joins(:policy_arf_report).merge(PolicyArfReport.of_policy(policy_id)) }

    scope :latest, -> {
      joins('INNER JOIN (SELECT host_id, policy_id, max(reports.id) AS id
                         FROM reports INNER JOIN foreman_openscap_policy_arf_reports
                             ON reports.id = foreman_openscap_policy_arf_reports.arf_report_id
                         GROUP BY host_id, policy_id) latest
             ON reports.id = latest.id')
    }

    scope :latest_of_policy, lambda { |policy|
      joins("INNER JOIN (SELECT host_id, policy_id, max(reports.id) AS id
                         FROM reports INNER JOIN foreman_openscap_policy_arf_reports
                            ON reports.id = foreman_openscap_policy_arf_reports.arf_report_id
                         WHERE policy_id = #{policy.id}
                         GROUP BY host_id, policy_id) latest
             ON reports.id = latest.id")
    }

    scope :with_score, lambda { where.not(:score => nil) }
    scope :passed, lambda { with_score.includes(:policy).where('foreman_openscap_policies.treshold <= reports.score') }
    scope :failed, lambda { where.not(:id => ArfReport.passed.pluck(:id)) }

    scope :by_rule_result, lambda { |rule_name, rule_result| joins(:sources).where(:sources => { :value => rule_name }, :logs => { :result => rule_result }) }

    def self.bit_mask(status)
      ComplianceStatus.bit_mask(status)
    end

    def self.report_status_column
      "status"
    end

    def status=(st)
      s = case st
          when Integer
            st
          when Hash, ActionController::Parameters
            ArfReportStatusCalculator.new(:counters => st).calculate
          else
            raise "Unsupported report status format #{st.class}"
          end
      write_attribute(:status, s)
    end

    delegate :status, :status_of, :to => :calculator
    delegate(*METRIC, :to => :calculator)

    def calculator
      ArfReportStatusCalculator.new(:bit_field => read_attribute(self.class.report_status_column))
    end

    def passed
      status_of "passed"
    end

    def failed
      status_of("failed") + status_of("othered")
    end

    def rules_count
      status.values.sum
    end

    def self.create_arf(asset, proxy, params)
      arf_report = nil
      policy = Policy.find_by :id => params[:policy_id]
      return unless policy

      ArfReport.transaction do
        arf_report = ArfReport.create(:host => asset.host,
                                      :reported_at => Time.at(params[:date].to_i),
                                      :status => params[:metrics],
                                      :metrics => params[:metrics],
                                      :score => params[:score],
                                      :openscap_proxy => proxy)
        return arf_report unless arf_report.persisted?
        PolicyArfReport.where(:arf_report_id => arf_report.id, :policy_id => policy.id, :digest => params[:digest]).first_or_create!
        if params[:logs]
          params[:logs].each do |log|
            src = Source.find_or_create_by(value: log[:source])
            msg = nil
            if src.logs.count > 0
              msg = Log.where(:source_id => src.id).order(:id => :desc).first.message
              update_msg_with_changes(msg, log)
            else
              if (msg = Message.find_by(:value => log[:title]))
                msg.attributes = {
                  :value => N_(log[:title]),
                  :severity => log[:severity],
                  :description => newline_to_space(log[:description]),
                  :rationale => newline_to_space(log[:rationale]),
                  :scap_references => references_links(log[:references]),
                  :fixes => fixes(log[:fixes])
                }
              else
                msg = Message.new(:value => N_(log[:title]),
                                  :severity => log[:severity],
                                  :description => newline_to_space(log[:description]),
                                  :rationale => newline_to_space(log[:rationale]),
                                  :scap_references => references_links(log[:references]),
                                  :fixes => fixes(log[:fixes]))
              end
              msg.save!
            end
            # TODO: log level
            Log.create!(:source_id => src.id,
                        :message_id => msg.id,
                        :level => :info,
                        :result => log[:result],
                        :report => arf_report)
          end
        end
      end
      arf_report
    end

    def assign_locations_organizations
      if host
        self.location_ids = [host.location_id]
        self.organization_ids = [host.organization_id]
      end
    end

    def failed?
      !passed?
    end

    def passed?
      score && score >= policy.treshold
    end

    def to_html
      openscap_proxy_api.arf_report_html(self, ForemanOpenscap::Helper::find_name_or_uuid_by_host(host))
    end

    def to_bzip
      openscap_proxy_api.arf_report_bzip(self, ForemanOpenscap::Helper::find_name_or_uuid_by_host(host))
    end

    def equal?(other)
      results = [logs, other.logs].flatten.group_by(&:source_id).values
      # for each rule, there should be one result from both reports
      return false unless results.map(&:length).all? { |item| item == 2 }
      results.all? { |result| result.first.source_id == result.last.source_id } &&
        host_id == other.host_id &&
        policy.id == other.policy.id
    end

    def destroy_from_proxy
      if !host
        destroy_from_proxy_warning "host"
      elsif !policy
        destroy_from_proxy_warning "policy"
      elsif !openscap_proxy
        destroy_from_proxy_warning "OpenSCAP proxy"
      else
        openscap_proxy_api.destroy_report(self, ForemanOpenscap::Helper::find_name_or_uuid_by_host(host))
      end
    end

    def destroy_from_proxy_warning(associated)
      logger.warn "Skipping deletion of report with id #{id} from proxy, no #{associated} associated with report"
      true
    end

    def self.newline_to_space(string)
      string.gsub(/ *\n+/, " ")
    end

    def self.references_links(references)
      return if references.nil?
      html_links = []
      references.each do |reference|
        next if reference['title'] == 'test_attestation' # A blank url created by OpenSCAP
        reference['html_link'] = "<a href='#{reference['href']}'>#{reference['href']}</a>" if reference['title'].blank?
        html_links << reference['html_link']
      end
      html_links.join(', ')
    end

    def self.fixes(raw_fixes)
      return if raw_fixes.empty?

      JSON.fast_generate(raw_fixes)
    end

    def self.update_msg_with_changes(msg, incoming_data)
      msg.severity = incoming_data['severity']
      msg.description = incoming_data['description']
      msg.rationale = incoming_data['rationale']
      msg.scap_references = incoming_data['references']
      msg.value = incoming_data['title']
      msg.fixes = fixes(incoming_data['fixes'])

      return unless msg.changed?
      msg.save
    end
  end
end

module ForemanOpenscap
  class ComplianceStatus < ::HostStatus::Status
    COMPLIANT = 0
    INCONCLUSIVE = 1
    INCOMPLIANT = 2

    def self.status_name
      N_('Compliance')
    end

    def status_link
      host.arf_reports_path(:search => "host = #{host.name}")
    end

    def self.bit_mask(status)
      "#{ArfReport::BIT_NUM * ArfReport::METRIC.index(status)} & #{ArfReport::MAX}"
    end

    def to_label(options = {})
      case to_status
      when COMPLIANT
        N_('Compliant')
      when INCONCLUSIVE
        N_('Inconclusive')
      when INCOMPLIANT
        N_('Incompliant')
      else
        N_('Unknown Compliance status')
      end
    end

    def to_global(options = {})
      case to_status
      when COMPLIANT
        ::HostStatus::Global::OK
      when INCONCLUSIVE
        ::HostStatus::Global::WARN
      else
        ::HostStatus::Global::ERROR
      end
    end

    def relevant?(options = {})
      # May fail host status during migration
      return false unless ForemanOpenscap::Asset.table_exists?
      host.policies.present?
    end

    def to_status(options = {})
      latest_reports = host.policies.map { |p| host.last_report_for_policy p }.flatten
      return INCOMPLIANT if latest_reports.any?(&:failed?)
      COMPLIANT
    end
  end
end

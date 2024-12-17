module Foreman::Controller::Parameters::PolicyApi
  extend ActiveSupport::Concern

  class_methods do
    def filter_params_list
      [:description, :name, :treshold, :period, :scap_content_id, :scap_content_profile_id, :deploy_by,
       :weekday, :day_of_month, :cron_line, :tailoring_file_id, :tailoring_file_profile_id,
       :location_ids => [], :organization_ids => [], :hostgroup_ids => [], :host_ids => []]
    end

    def policy_params_filter
      Foreman::ParameterFilter.new(::ForemanOpenscap::Policy).tap do |filter|
        filter.permit filter_params_list
      end
    end
  end

  def policy_params
    self.class.policy_params_filter.filter_params(params, parameter_filter_context)
  end
end

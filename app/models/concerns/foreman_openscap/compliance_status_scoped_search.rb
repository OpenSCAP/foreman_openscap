module ForemanOpenscap
  module ComplianceStatusScopedSearch
    extend ActiveSupport::Concern

    module ClassMethods
      def policy_search(search_alias)
        scoped_search :relation => :policy, :on => :name, :complete_value => true, :rename => search_alias,
              :only_explicit => true
      end

      def search_by_comply_with(_key, _operator, policy_name)
        search_by_policy_results policy_name, &:passed
      end

      def search_by_not_comply_with(_key, _operator, policy_name)
        search_by_policy_results policy_name, &:failed
      end

      def search_by_policy_results(policy_name, &selection)
        scope = ArfReport.of_policy(Policy.find_by(:name => policy_name).id)
                         .instance_eval(&selection)
        query_conditions_from_scope scope
      end

      def search_by_rule_failed(key, operator, rule_name)
        search_by_rule rule_name, "fail"
      end

      def search_by_rule_passed(key, operator, rule_name)
        search_by_rule rule_name, "pass"
      end

      def search_by_rule_othered(key, operator, rule_name)
        search_by_rule rule_name, LogExtensions.othered_result_constants
      end

      def search_by_last_for(key, operator, by)
        by.gsub!(/[^[:alnum:]]/, '')
        case by.downcase
        when 'host'
          { :conditions => "reports.id IN (
                SELECT MAX(id) FROM reports sub
                WHERE sub.type = 'ForemanOpenscap::ArfReport'
                  AND sub.host_id = reports.host_id )" }
        when 'policy'
          { :conditions => 'reports.id IN (
              SELECT latest.id
              FROM foreman_openscap_policies
                INNER JOIN (SELECT policy_id, MAX(reports.id) AS id
                            FROM reports INNER JOIN foreman_openscap_policy_arf_reports
                              ON reports.id = foreman_openscap_policy_arf_reports.arf_report_id
                            GROUP BY policy_id
                           ) latest
                ON foreman_openscap_policies.id = latest.policy_id)' }
        else
          raise "Cannot search last by #{by}"
        end
      end

      def search_by_compliance_status(key, operator, value)
        scope = case value
                when 'compliant'
                  ArfReport.passed
                when 'incompliant'
                  ArfReport.failed
                end
        query_conditions_from_scope scope
      end

      def search_by_host_collection_name(key, operator, value)
        scope = apply_condition(::Host.joins(:host_collections),
                                operator == '<>',
                                :katello_host_collections => { :name => value })
        query_conditions_from_scope ForemanOpenscap::ArfReport.where(:host_id => scope)
      end

      private

      def query_conditions_from_scope(scope)
        query = scope.select(ArfReport.arel_table[:id]).to_sql
        query_conditions query
      end

      def query_conditions(query)
        { :conditions => "reports.id IN (#{query})" }
      end

      def search_by_rule(rule_name, rule_result)
        query = ArfReport.by_rule_result(rule_name, rule_result)
                         .select(ArfReport.arel_table[:id]).to_sql

        query_conditions query
      end

      def apply_condition(scope, negate, conditions)
        if negate
          scope.where.not(conditions)
        else
          scope.where(conditions)
        end
      end
    end

    included do
      if ForemanOpenscap.with_katello?
        has_one :content_facet, :through => :host
        has_many :content_view_environment_content_facets, through: :content_facet, class_name: 'Katello::ContentViewEnvironmentContentFacet'
        has_many :content_view_environments, through: :content_view_environment_content_facets
        has_many :content_views, through: :content_view_environments
        has_many :lifecycle_environments, through: :content_view_environments

        has_many :host_collections, :through => :host

        scoped_search :relation => :lifecycle_environments, :on => :name, :complete_value => true, :rename => :lifecycle_environment
        scoped_search :relation => :host_collections, :on => :name, :complete_value => true, :rename => :host_collection,
                      :operators => ['= ', '!= '], :ext_method => :search_by_host_collection_name
      end

      policy_search :compliance_policy

      policy_search :policy

      scoped_search :on => :id, :rename => :last_for, :complete_value => { :host => 0, :policy => 1 },
                    :only_explicit => true, :operators => ['= '], :ext_method => :search_by_last_for

      scoped_search :relation => :policy, :on => :name, :complete_value => true, :rename => :comply_with,
                    :only_explicit => true, :operators => ['= '], :ext_method => :search_by_comply_with

      scoped_search :relation => :policy, :on => :name, :complete_value => true, :rename => :not_comply_with,
                    :only_explicit => true, :operators => ['= '], :ext_method => :search_by_not_comply_with

      scoped_search :relation => :openscap_proxy, :on => :name, :complete_value => true, :only_explicit => true, :rename => :openscap_proxy

      scoped_search :relation => :sources, :on => :value, :rename => :xccdf_rule_name,
                    :only_explicit => true, :operators => ['= ']

      scoped_search :relation => :sources, :on => :value, :rename => :xccdf_rule_failed,
                    :only_explicit => true, :operators => ['= '], :ext_method => :search_by_rule_failed

      scoped_search :relation => :sources, :on => :value, :rename => :xccdf_rule_passed,
                    :only_explicit => true, :operators => ['= '], :ext_method => :search_by_rule_passed

      scoped_search :relation => :sources, :on => :value, :rename => :xccdf_rule_othered,
                    :only_explicit => true, :operators => ['= '], :ext_method => :search_by_rule_othered

      scoped_search :on => :status, :rename => :compliance_status, :operators => ['= '],
                           :ext_method => :search_by_compliance_status,
                           :complete_value => { :compliant => ::ForemanOpenscap::ComplianceStatus::COMPLIANT,
                                                :incompliant => ::ForemanOpenscap::ComplianceStatus::INCOMPLIANT },
                           :validator => ->(value) { ['compliant', 'incompliant'].reduce(false) { |memo, item| memo || (item == value) } }
    end
  end
end

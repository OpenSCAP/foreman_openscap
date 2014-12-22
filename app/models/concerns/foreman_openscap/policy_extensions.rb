#
# Copyright (c) 2014 Red Hat Inc.
#
# This software is licensed to you under the GNU General Public License,
# version 3 (GPLv3). There is NO WARRANTY for this software, express or
# implied, including the implied warranties of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv3
# along with this software; if not, see http://www.gnu.org/licenses/gpl.txt
#

require 'scaptimony/policy'

module ForemanOpenscap
  module PolicyExtensions
    extend ActiveSupport::Concern
    include Authorizable
    include Taxonomix
    included do
      attr_accessible :description, :name, :period, :scap_content_id, :scap_content_profile_id, :weekday, :location_ids, :organization_ids

      scoped_search :on => :name, :complete_value => true

      default_scope lambda {
                      with_taxonomy_scope do
                        order("scaptimony_policies.name")
                      end
                    }
    end

    def used_location_ids
      Location.joins(:taxable_taxonomies).where(
              'taxable_taxonomies.taxable_type' => 'Scaptimony::Policy',
              'taxable_taxonomies.taxable_id' => id).pluck(:id)
    end

    def used_organization_ids
      Organization.joins(:taxable_taxonomies).where(
              'taxable_taxonomies.taxable_type' => 'Scaptimony::Policy',
              'taxable_taxonomies.taxable_id' => id).pluck(:id)
    end

    def assign_hosts(hosts)
      assign_assets hosts.map &:get_asset
    end
  end
end

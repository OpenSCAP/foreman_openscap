class RemoveDeletedPolicy < ActiveRecord::Migration[4.2]
  def up
    ForemanOpenscap::AssetPolicy.all.collect(&:policy_id).uniq.each do |policy_id|
      execute("DELETE FROM foreman_openscap_asset_policies WHERE policy_id = '#{policy_id}';") if ForemanOpenscap::Policy.unscoped.find_by(id: policy_id).nil?
    end
  end

  def down
  end
end

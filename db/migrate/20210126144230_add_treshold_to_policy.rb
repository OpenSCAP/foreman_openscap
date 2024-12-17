class AddTresholdToPolicy < ActiveRecord::Migration[6.0]
  def change
    add_column :foreman_openscap_policies, :treshold, :numeric, :null => false, :default => 100
    add_column :reports, :score, :numeric
  end
end

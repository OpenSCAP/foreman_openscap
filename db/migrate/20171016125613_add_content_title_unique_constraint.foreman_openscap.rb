class AddContentTitleUniqueConstraint < ActiveRecord::Migration[4.2]
  def change
    remove_index :foreman_openscap_scap_contents, :name => 'index_scaptimony_scap_contents_on_title'
    add_index :foreman_openscap_scap_contents, :title, :unique => true
  end
end

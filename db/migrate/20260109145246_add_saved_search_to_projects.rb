class AddSavedSearchToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :saved_searches, :archived, :boolean, default: false, null: false
    add_reference :projects, :saved_search, null: true, foreign_key: true
    add_index :saved_searches, :archived
  end
end

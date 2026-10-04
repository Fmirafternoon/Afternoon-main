class AddStatusToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :status, :string, default: "importing"
    add_index :candidates, :status
  end
end

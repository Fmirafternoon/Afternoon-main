class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :title
      t.string :position_name
      t.string :contract_type
      t.date :start_date
      t.integer :status
      t.boolean :alerts_enabled
      t.references :customer, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end

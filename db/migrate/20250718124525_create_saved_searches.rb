class CreateSavedSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :saved_searches do |t|
      t.string :name, null: false
      t.jsonb :criteria, null: false, default: {}
      t.references :customer, null: false, foreign_key: { to_table: :users }
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :saved_searches, [:customer_id, :last_used_at]
  end
end

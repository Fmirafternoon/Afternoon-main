class CreateBasketItems < ActiveRecord::Migration[8.0]
  def change
    create_table :basket_items do |t|
      t.references :basket, null: false, foreign_key: true
      t.references :agent, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "pending"
      t.datetime :meeting_date
      t.text :customer_message

      t.timestamps
    end

    add_index :basket_items, [:basket_id, :agent_id], unique: true
    add_index :basket_items, :status
  end
end

class CreateBaskets < ActiveRecord::Migration[8.0]
  def change
    create_table :baskets do |t|
      t.references :customer, null: false, foreign_key: { to_table: :users }, index: { unique: true }

      t.timestamps
    end
  end
end

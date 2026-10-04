class CreateEmployments < ActiveRecord::Migration[8.0]
  def change
    create_table :employments do |t|
      t.string :title
      t.references :candidate, null: false, foreign_key: true
      t.string :company
      t.text :description
      t.integer :duration_in_months
      t.integer :from_year
      t.integer :from_month
      t.integer :to_year
      t.integer :to_month
      t.string :location

      t.timestamps
    end
  end
end

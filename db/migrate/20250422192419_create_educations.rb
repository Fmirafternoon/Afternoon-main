class CreateEducations < ActiveRecord::Migration[8.0]
  def change
    create_table :educations do |t|
      t.string :title
      t.references :candidate, null: false, foreign_key: true
      t.string :location
      t.string :issuing_organization
      t.integer :duration_in_months
      t.integer :from_year
      t.integer :from_month
      t.integer :to_year
      t.integer :to_month

      t.timestamps
    end
  end
end

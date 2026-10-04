class CreateCompanyLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :company_locations do |t|
      t.references :company, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true

      t.timestamps
    end
  end
end

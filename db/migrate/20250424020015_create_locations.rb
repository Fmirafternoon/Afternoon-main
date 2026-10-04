class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.string :city
      t.string :zip_code
      t.float :latitude
      t.float :longitude

      t.timestamps
    end
  end
end

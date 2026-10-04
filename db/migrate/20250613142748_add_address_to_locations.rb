class AddAddressToLocations < ActiveRecord::Migration[8.0]
  def change
    add_column :locations, :address, :string
  end
end

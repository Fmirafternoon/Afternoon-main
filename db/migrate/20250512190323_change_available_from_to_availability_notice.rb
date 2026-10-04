class ChangeAvailableFromToAvailabilityNotice < ActiveRecord::Migration[8.0]
  def change
    rename_column :candidates, :available_from, :availability_notice
    change_column :candidates, :availability_notice, :string
  end
end

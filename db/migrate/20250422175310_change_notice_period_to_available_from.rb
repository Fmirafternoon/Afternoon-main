class ChangeNoticePeriodToAvailableFrom < ActiveRecord::Migration[8.0]
  def change
    remove_column :candidates, :notice_period
    add_column :candidates, :available_from, :date, default: -> { 'NOW()' }
  end
end

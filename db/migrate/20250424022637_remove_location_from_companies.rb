class RemoveLocationFromCompanies < ActiveRecord::Migration[8.0]
  def change
    remove_reference :companies, :location, null: false, foreign_key: true
  end
end

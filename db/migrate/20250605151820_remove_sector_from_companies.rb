class RemoveSectorFromCompanies < ActiveRecord::Migration[8.0]
  def change
    remove_column :companies, :sector
  end
end

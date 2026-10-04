class AddSectorToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :sector, :string
  end
end

class RenameSiretToSiren < ActiveRecord::Migration[8.0]
  def change
    rename_column :companies, :siret, :siren
  end
end

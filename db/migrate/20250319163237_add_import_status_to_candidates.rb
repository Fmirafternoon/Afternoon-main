class AddImportStatusToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :import_status, :string
  end
end

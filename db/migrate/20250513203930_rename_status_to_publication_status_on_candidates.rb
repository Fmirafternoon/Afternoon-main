class RenameStatusToPublicationStatusOnCandidates < ActiveRecord::Migration[8.0]
  def change
    rename_column :candidates, :status, :publication_status
  end
end

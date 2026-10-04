class CreateCandidateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :candidate_documents do |t|
      t.string :url, null: false
      t.string :file_name, null: false
      t.references :candidate, null: false, foreign_key: true

      t.timestamps
    end
  end
end

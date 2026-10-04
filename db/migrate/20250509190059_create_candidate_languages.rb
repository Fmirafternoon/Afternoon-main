class CreateCandidateLanguages < ActiveRecord::Migration[8.0]
  def change
    create_table :candidate_languages do |t|
      t.string :code
      t.string :level
      t.references :candidate, null: false, foreign_key: true

      t.timestamps
    end
  end
end

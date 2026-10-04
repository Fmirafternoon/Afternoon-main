class CreateCandidateSectors < ActiveRecord::Migration[8.0]
  def change
    create_table :candidate_sectors do |t|
      t.references :candidate, null: false, foreign_key: true
      t.references :sector, null: false, foreign_key: true

      t.timestamps
    end
  end
end

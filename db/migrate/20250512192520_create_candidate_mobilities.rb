class CreateCandidateMobilities < ActiveRecord::Migration[8.0]
  def change
    create_table :candidate_mobilities do |t|
      t.references :candidate, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true

      t.timestamps
    end
  end
end

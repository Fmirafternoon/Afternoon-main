class CreateProjectCandidates < ActiveRecord::Migration[8.0]
  def change
    create_table :project_candidates do |t|
      t.references :project, null: false, foreign_key: true
      t.references :candidate, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.decimal :match_score, precision: 5, scale: 4
      t.datetime :viewed_at
      t.datetime :interest_expressed_at
      t.text :interest_message
      t.jsonb :llm_analysis, default: {}
      t.string :pdf_url

      t.timestamps
    end

    add_index :project_candidates, [:project_id, :candidate_id], unique: true
  end
end

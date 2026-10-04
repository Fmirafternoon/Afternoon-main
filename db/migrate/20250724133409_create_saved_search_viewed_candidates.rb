class CreateSavedSearchViewedCandidates < ActiveRecord::Migration[8.0]
  def change
    create_table :saved_search_viewed_candidates do |t|
      t.references :saved_search, null: false, foreign_key: true
      t.references :candidate, null: false, foreign_key: true
      t.datetime :viewed_at, null: false

      t.timestamps
    end

    add_index :saved_search_viewed_candidates,
              [:saved_search_id, :candidate_id],
              unique: true,
              name: 'idx_unique_saved_search_candidate'
  end
end

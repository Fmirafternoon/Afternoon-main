class CreateBasketItemCandidates < ActiveRecord::Migration[8.0]
  def change
    create_table :basket_item_candidates do |t|
      t.references :basket_item, null: false, foreign_key: true
      t.references :candidate, null: false, foreign_key: true
      t.datetime :added_at, null: false

      t.timestamps
    end

    add_index :basket_item_candidates, [:basket_item_id, :candidate_id], unique: true, name: "idx_unique_basket_item_candidate"
  end
end

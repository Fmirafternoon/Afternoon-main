class CreateEmbeddingCaches < ActiveRecord::Migration[8.0]
  def change
    create_table :embedding_caches do |t|
      t.string :text_hash, null: false
      t.text :text, null: false
      t.vector :embedding, limit: 1024, null: false
      t.integer :usage_count, default: 0, null: false
      t.datetime :last_used_at
      
      t.timestamps
    end
    
    add_index :embedding_caches, :text_hash, unique: true
    add_index :embedding_caches, :last_used_at
    add_index :embedding_caches, :usage_count
    add_index :embedding_caches, :created_at
  end
end

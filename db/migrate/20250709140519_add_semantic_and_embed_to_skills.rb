class AddSemanticAndEmbedToSkills < ActiveRecord::Migration[8.0]
  def change
    add_column :skills, :semantic, :jsonb, default: []
    add_column :skills, :embedding, :vector, limit: 1024
    add_index :skills, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
  end
end

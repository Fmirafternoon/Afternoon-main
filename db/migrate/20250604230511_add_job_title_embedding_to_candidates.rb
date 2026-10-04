class AddJobTitleEmbeddingToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :job_title_embedding, :vector, limit: 1024
    add_index :candidates, :job_title_embedding, using: :ivfflat, opclass: :vector_cosine_ops
  end
end

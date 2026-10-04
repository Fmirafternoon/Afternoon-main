class AddLastUpdatedAtToCandidate < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :last_updated_at, :date
  end
end

class AddDiscardedAtToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :discarded_at, :datetime
    add_index :candidates, :discarded_at
  end
end

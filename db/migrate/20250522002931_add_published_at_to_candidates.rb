class AddPublishedAtToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :published_at, :datetime
  end
end

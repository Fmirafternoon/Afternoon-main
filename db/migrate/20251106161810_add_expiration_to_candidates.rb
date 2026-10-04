class AddExpirationToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :expiration_notified_at, :datetime
    add_column :candidates, :expires_at, :datetime
    add_index :candidates, :expires_at
  end
end

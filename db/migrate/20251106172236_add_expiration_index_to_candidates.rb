class AddExpirationIndexToCandidates < ActiveRecord::Migration[8.0]
  def change
    # Composite index for optimizing the expiring_soon and expired scopes
    # This index will be used for queries like:
    # WHERE publication_status = 'published' AND expires_at <= ? AND expiration_notified_at IS NULL
    add_index :candidates,
              [:publication_status, :expires_at, :expiration_notified_at],
              name: 'index_candidates_on_expiration_query',
              comment: 'Optimize expiring_soon and expired scope queries'
  end
end

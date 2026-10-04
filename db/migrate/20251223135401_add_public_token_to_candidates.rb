class AddPublicTokenToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :public_token, :string, limit: 8

    reversible do |dir|
      dir.up do
        Candidate.find_each do |candidate|
          candidate.update_column(:public_token, SecureRandom.alphanumeric(6).upcase)
        end
      end
    end

    add_index :candidates, :public_token, unique: true
  end
end

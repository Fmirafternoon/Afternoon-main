class AddDiscardedAtToRecruitmentOffices < ActiveRecord::Migration[8.0]
  def change
    add_column :recruitment_offices, :discarded_at, :datetime
    add_index :recruitment_offices, :discarded_at
  end
end

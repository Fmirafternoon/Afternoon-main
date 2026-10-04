class AddRecruitmentOfficeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :recruitment_office, foreign_key: true
  end
end

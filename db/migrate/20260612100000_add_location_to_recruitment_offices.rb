class AddLocationToRecruitmentOffices < ActiveRecord::Migration[8.0]
  def change
    add_reference :recruitment_offices, :location, null: true, foreign_key: true
  end
end

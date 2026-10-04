class AddRecruitmentCommissionToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :recruitment_commission, :integer
  end
end

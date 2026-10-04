class AddSeniorityAndExperienceToCandidateSkills < ActiveRecord::Migration[8.0]
  def change
    add_column :candidate_skills, :seniority, :integer
    add_column :candidate_skills, :experience, :text
  end
end

class AddSeniorityToProjectSkills < ActiveRecord::Migration[8.0]
  def change
    add_column :project_skills, :seniority, :integer
  end
end

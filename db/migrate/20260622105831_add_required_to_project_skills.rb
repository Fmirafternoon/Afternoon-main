class AddRequiredToProjectSkills < ActiveRecord::Migration[8.0]
  def change
    add_column :project_skills, :required, :boolean, null:false, default:false
    
  end
end

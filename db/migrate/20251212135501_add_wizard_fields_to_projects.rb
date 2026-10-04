class AddWizardFieldsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_reference :projects, :location, foreign_key: true
    add_column :projects, :description, :text
    add_column :projects, :min_experience_years, :integer
    add_column :projects, :education_level, :string
    add_column :projects, :languages, :jsonb, default: []
    add_column :projects, :target_salary, :integer
    add_column :projects, :desired_availability, :string
  end
end

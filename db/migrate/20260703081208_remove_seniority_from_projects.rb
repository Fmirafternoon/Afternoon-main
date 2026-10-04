class RemoveSeniorityFromProjects < ActiveRecord::Migration[8.0]
  def change
    remove_column :projects, :seniority, :integer
  end
end

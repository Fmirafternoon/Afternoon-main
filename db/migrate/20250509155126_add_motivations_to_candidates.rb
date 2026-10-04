class AddMotivationsToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :change_motivations, :text
    add_column :candidates, :ongoing_application, :boolean
    add_column :candidates, :career_relevance, :text
  end
end

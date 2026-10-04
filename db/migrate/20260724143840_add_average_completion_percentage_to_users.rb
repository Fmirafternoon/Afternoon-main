class AddAverageCompletionPercentageToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :average_completion_percentage, :integer
  end
end

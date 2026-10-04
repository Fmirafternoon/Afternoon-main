class AddSectorToEmployments < ActiveRecord::Migration[8.0]
  def change
    add_column :employments, :sector, :string
  end
end

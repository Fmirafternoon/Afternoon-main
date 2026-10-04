class CreateCandidates < ActiveRecord::Migration[8.0]
  def change
    create_table :candidates do |t|
      t.string :first_name
      t.string :last_name
      t.string :position
      t.string :resume_url
      t.string :resume_file_name
      t.references :users, :agent, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end

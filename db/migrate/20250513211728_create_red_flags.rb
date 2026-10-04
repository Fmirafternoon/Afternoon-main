class CreateRedFlags < ActiveRecord::Migration[8.0]
  def change
    create_table :red_flags do |t|
      t.references :candidate, null: false, foreign_key: true
      t.string :slug
      t.integer :score
      t.text :question
      t.text :answer

      t.timestamps
    end
  end
end

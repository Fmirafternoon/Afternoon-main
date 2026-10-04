class CreateTrainings < ActiveRecord::Migration[8.0]
  def change
    create_table :trainings do |t|
      t.string :title
      t.integer :year
      t.string :issuing_organization
      t.references :candidate, null: false, foreign_key: true

      t.timestamps
    end
  end
end

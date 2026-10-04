class CreateSectors < ActiveRecord::Migration[8.0]
  def change
    create_table :sectors do |t|
      t.string :name
      t.string :slug

      t.timestamps
    end
  end
end

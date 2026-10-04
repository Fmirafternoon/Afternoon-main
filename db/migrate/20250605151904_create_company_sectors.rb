class CreateCompanySectors < ActiveRecord::Migration[8.0]
  def change
    create_table :company_sectors do |t|
      t.references :company, null: false, foreign_key: true
      t.references :sector, null: false, foreign_key: true

      t.timestamps
    end
  end
end

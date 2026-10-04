class CreateCompanyPositions < ActiveRecord::Migration[8.0]
  def change
    create_table :company_positions do |t|
      t.string :title
      t.references :company, null: false, foreign_key: true

      t.timestamps
    end
  end
end

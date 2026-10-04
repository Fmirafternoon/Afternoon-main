class CreateReferrals < ActiveRecord::Migration[8.0]
  def change
    create_table :referrals do |t|
      t.string :first_name
      t.string :last_name
      t.string :phone_number
      t.string :email
      t.string :company
      t.string :position
      t.text :description
      t.references :candidate, null: false, foreign_key: true

      t.timestamps
    end
  end
end

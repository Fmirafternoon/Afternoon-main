class CreateRecruitmentOffices < ActiveRecord::Migration[8.0]
  def change
    create_table :recruitment_offices do |t|
      t.string :name
      t.string :url
      t.string :siret_number
      t.string :vat_number
      t.string :address
      t.string :city
      t.string :zip_code

      t.timestamps
    end
  end
end

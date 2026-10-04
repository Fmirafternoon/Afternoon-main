class CreatePartnerCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :partner_companies do |t|
      t.references :recruitment_office, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true

      t.timestamps
    end

    add_index :partner_companies, [:recruitment_office_id, :company_id], unique: true
  end
end

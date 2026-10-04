class AddResumeFieldsToCandidates < ActiveRecord::Migration[8.0]
  def change
    add_column :candidates, :gender, :string
    add_column :candidates, :description, :text
    add_column :candidates, :birth_year, :integer
    add_column :candidates, :email, :string
    add_column :candidates, :address, :string
    add_column :candidates, :phone_number, :string
    add_column :candidates, :total_experience_in_years, :integer
    add_column :candidates, :has_driving_license, :boolean
    add_column :candidates, :has_a_car, :boolean
    add_column :candidates, :notice_period, :string
    add_column :candidates, :contract_type, :string
    add_column :candidates, :salary_expectation, :integer
    add_column :candidates, :skills, :text, array: true, default: []
  end
end

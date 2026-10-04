class Company < ApplicationRecord
  has_many :company_locations, dependent: :destroy
  has_many :locations, through: :company_locations
  has_many :users
  has_many :positions, dependent: :destroy, class_name: "CompanyPosition"
  has_many :partner_companies, dependent: :destroy
  has_many :recruitment_offices, through: :partner_companies
  has_many :company_sectors, dependent: :destroy
  has_many :sectors, through: :company_sectors

  accepts_nested_attributes_for :locations, allow_destroy: true
end

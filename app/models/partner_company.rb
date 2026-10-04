class PartnerCompany < ApplicationRecord
  belongs_to :recruitment_office
  belongs_to :company

  validates :recruitment_office_id, uniqueness: { scope: :company_id }

  delegate :name, to: :company
end

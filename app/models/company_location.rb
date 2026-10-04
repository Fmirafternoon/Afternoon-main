class CompanyLocation < ApplicationRecord
  belongs_to :company
  belongs_to :location

  delegate :name, to: :location
end

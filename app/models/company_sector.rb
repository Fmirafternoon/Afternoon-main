class CompanySector < ApplicationRecord
  belongs_to :company
  belongs_to :sector
end

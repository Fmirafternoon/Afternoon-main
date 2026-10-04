FactoryBot.define do
  factory :company_sector do
    association :company
    association :sector
  end
end
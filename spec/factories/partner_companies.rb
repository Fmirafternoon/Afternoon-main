FactoryBot.define do
  factory :partner_company do
    association :recruitment_office
    association :company
  end
end
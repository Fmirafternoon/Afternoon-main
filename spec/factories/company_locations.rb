FactoryBot.define do
  factory :company_location do
    association :company
    association :location
  end
end
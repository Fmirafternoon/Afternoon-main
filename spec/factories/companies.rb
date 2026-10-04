FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Company #{n}" }
    sequence(:siren) { |n| "#{123456789 + n}" }
  end
end
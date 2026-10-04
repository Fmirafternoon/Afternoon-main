FactoryBot.define do
  factory :basket do
    association :customer, factory: [:user, :customer]
  end
end

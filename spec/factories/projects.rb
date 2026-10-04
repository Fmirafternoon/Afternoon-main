FactoryBot.define do
  factory :project do
    sequence(:title) { |n| "Projet #{n}" }
    sequence(:position_name) { |n| "Chef de cuisine #{n}" }
    contract_type { "cdi" }
    start_date { 1.month.from_now }
    status { :active }
    alerts_enabled { true }
    association :customer, factory: :user

    trait :broadcast_enabled do
      broadcast_enabled { true }
    end
  end
end

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    first_name { "John" }
    last_name { "Doe" }

    # Default to customer role
    role { "customer" }

    trait :customer do
      role { "customer" }
      phone_number { "+33612345678" }
      company { association :company }
      terms_accepted_at { 1.day.ago }
    end

    trait :agent_user do
      role { "agent_user" }
      recruitment_office { association :recruitment_office }
    end

    trait :agent_manager do
      role { "agent_manager" }
      recruitment_office { association :recruitment_office }
      terms_accepted_at { 1.day.ago }
    end

    trait :super_admin do
      role { "super_admin" }
    end

    trait :with_saved_searches do
      after(:create) do |user|
        create_list(:saved_search, 3, customer: user)
      end
    end
  end
end
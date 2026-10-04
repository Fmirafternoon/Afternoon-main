FactoryBot.define do
  factory :recruitment_office do
    sequence(:name) { |n| "Recruitment Office #{n}" }
    sequence(:siret_number) { |n| "#{12345678900000 + n}" }
    url { "https://example.com" }
    address { "123 Main Street" }
    city { "Paris" }
    zip_code { "75001" }

    trait :with_location do
      location { association :location }
    end

    trait :discarded do
      discarded_at { 1.day.ago }
    end
  end
end
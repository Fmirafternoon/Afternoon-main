FactoryBot.define do
  factory :employment do
    candidate { association :candidate }
    title { "Développeur Senior" }
    company { "TechCorp" }
    from_month { 1 }
    from_year { 2020 }
    to_month { 12 }
    to_year { 2022 }
    location { "Paris" }
    sector { "IT" }
    description { "Développement d'applications web avec Ruby on Rails" }
    duration_in_months { 24 }

    trait :current do
      to_month { nil }
      to_year { nil }
    end

    trait :short_term do
      from_month { 6 }
      from_year { 2022 }
      to_month { 9 }
      to_year { 2022 }
    end
  end
end

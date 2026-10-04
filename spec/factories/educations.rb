FactoryBot.define do
  factory :education do
    candidate { association :candidate }
    title { "Master en Informatique" }
    issuing_organization { "Université de Paris" }
    location { "Paris, France" }
    from_month { 9 }
    from_year { 2018 }
    to_month { 6 }
    to_year { 2020 }
    duration_in_months { 24 }

    trait :without_end_date do
      to_month { nil }
      to_year { nil }
    end

    trait :current do
      to_month { nil }
      to_year { nil }
    end
  end
end

FactoryBot.define do
  factory :candidate_language do
    candidate { association :candidate }
    code { "fr" }
    level { "C2" }

    trait :english do
      code { "en" }
      level { "B2" }
    end

    trait :spanish do
      code { "es" }
      level { "A2" }
    end

    trait :native do
      level { "C2" }
    end

    trait :beginner do
      level { "A1" }
    end
  end
end

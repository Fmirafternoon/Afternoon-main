FactoryBot.define do
  factory :red_flag do
    candidate { association :candidate }
    slug { "missing_info" }
    score { 1 }
    question { "Information manquante dans le CV" }
    answer { nil }

    trait :answered do
      answer { "Information corrigée" }
    end

    trait :unanswered do
      answer { nil }
    end

    trait :experience_gap do
      slug { "experience_gap" }
      question { "Trou dans l'expérience professionnelle" }
    end

    trait :qualification_mismatch do
      slug { "qualification_mismatch" }
      question { "Qualifications ne correspondent pas au poste" }
    end
  end
end

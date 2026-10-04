FactoryBot.define do
  factory :project_candidate do
    project
    candidate
    status { :matched }
    llm_analysis { {} }

    trait :pushed do
      status { :pushed }
      pushed_at { Time.current }
    end

    trait :interested do
      status { :interested }
      pushed_at { 1.week.ago }
      interest_expressed_at { Time.current }
    end

    trait :with_llm_analysis do
      llm_analysis do
        {
          "strengths" => ["Experience en restaurant etoile", "Management d'equipe"],
          "attention_points" => ["Pretentions salariales elevees"],
          "summary" => "Candidat experimente avec profil de manager"
        }
      end
      llm_analyzed_at { Time.current }
    end
  end
end

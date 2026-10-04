FactoryBot.define do
  factory :candidate do
    agent { association :user, :agent_user }
    publication_status { "draft" }
    import_status { "uploading" }
    first_name { "John" }
    last_name { "Doe" }
    sequence(:email) { |n| "john.doe#{n}@example.com" }
    phone_number { "+33612345678" }
    birth_year { 30.years.ago.year }
    position { "Software Developer" }
    job_title_embedding { nil } # Default to nil, use :with_embedding trait for embeddings

    trait :with_embedding do
      job_title_embedding { Array.new(1024) { rand } }
    end

    trait :with_skills do
      after(:create) do |candidate|
        create_list(:candidate_skill, 3, candidate: candidate)
      end
    end

    trait :with_sectors do
      after(:create) do |candidate|
        create_list(:candidate_sector, 2, candidate: candidate)
      end
    end

    trait :with_resume do
      resume_url { "https://example.com/resume.pdf" }
      resume_file_name { "resume.pdf" }
    end
  end
end

FactoryBot.define do
  factory :training do
    candidate { association :candidate }
    title { "Formation Ruby on Rails" }
    issuing_organization { "École 42" }
    year { 2023 }
  end
end
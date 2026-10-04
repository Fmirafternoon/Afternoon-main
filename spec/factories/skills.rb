FactoryBot.define do
  factory :skill do
    sequence(:name) { |n| "Skill #{n}" }
    embedding { Array.new(1024) { rand } }
  end
end
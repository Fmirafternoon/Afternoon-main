FactoryBot.define do
  factory :sector do
    sequence(:name) { |n| "Sector #{n}" }
    # slug will be auto-generated from name by the model's before_validation callback
  end
end
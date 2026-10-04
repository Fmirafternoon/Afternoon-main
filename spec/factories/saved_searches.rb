FactoryBot.define do
  factory :saved_search do
    association :customer, factory: [:user, :customer]
    sequence(:name) { |n| "Search #{n}" }
    criteria { { 'query' => 'test query' } }
    
    trait :with_full_criteria do
      criteria do
        {
          'query' => 'developer',
          'city' => 'Paris',
          'zip_code' => '75001',
          'lat' => 48.8566,
          'lng' => 2.3522,
          'autocomplete_address' => 'Paris, France',
          'sector_ids' => [1, 2, 3],
          'skills' => ['Ruby', 'Rails', 'JavaScript']
        }
      end
    end
    
    trait :recently_used do
      last_used_at { 1.hour.ago }
    end
  end
end
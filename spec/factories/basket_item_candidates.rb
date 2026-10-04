FactoryBot.define do
  factory :basket_item_candidate do
    basket_item
    candidate
    added_at { Time.current }
  end
end

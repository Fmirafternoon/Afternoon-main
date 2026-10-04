FactoryBot.define do
  factory :basket_item do
    basket
    association :agent, factory: [:user, :agent]
    status { "pending" }

    trait :meeting_requested do
      status { "meeting_requested" }
      meeting_date { 2.days.from_now }
      customer_message { "Je souhaite discuter de ces profils" }
    end

    trait :meeting_scheduled do
      status { "meeting_scheduled" }
      meeting_date { 2.days.from_now }
      customer_message { "Rendez-vous confirmé" }
    end

    trait :cancelled do
      status { "cancelled" }
    end
  end
end

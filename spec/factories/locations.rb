FactoryBot.define do
  factory :location do
    address { "1 rue de la Paix" }
    city { "Paris" }
    zip_code { "75001" }
    latitude { 48.8696 }
    longitude { 2.3312 }
  end
end
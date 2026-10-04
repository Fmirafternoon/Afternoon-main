FactoryBot.define do
  factory :referral do
    candidate { association :candidate }
    first_name { "Jean" }
    last_name { "Dupont" }
    company { "Tech Corp" }
    position { "Directeur Technique" }
    phone_number { "+33612345678" }
    email { "jean.dupont@example.com" }
    description { "Excellent développeur avec qui j'ai travaillé" }
  end
end
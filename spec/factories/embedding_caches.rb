FactoryBot.define do
  factory :embedding_cache do
    sequence(:text) { |n| "Conducteur de travaux #{n}" }
    text_hash { Digest::SHA256.hexdigest(text.downcase.strip) }
    embedding { Array.new(1024) { rand } }
    usage_count { 1 }
    last_used_at { Time.current }
  end
end
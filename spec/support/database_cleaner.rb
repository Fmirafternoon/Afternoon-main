require 'database_cleaner/active_record'

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner[:active_record].clean_with(:truncation, except: %w[ar_internal_metadata])
  end

  config.before(:each) do |example|
    if example.metadata[:type] == :request || example.metadata[:js]
      DatabaseCleaner[:active_record].strategy = :truncation
    else
      DatabaseCleaner[:active_record].strategy = :transaction
    end
    DatabaseCleaner[:active_record].start
  end

  config.after(:each) do
    DatabaseCleaner[:active_record].clean
  end
end
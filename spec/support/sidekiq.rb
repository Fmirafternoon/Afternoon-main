require 'sidekiq/testing'

# Disable Sidekiq jobs by default in test environment
Sidekiq::Testing.fake!

RSpec.configure do |config|
  # Clear jobs between tests
  config.before(:each) do
    Sidekiq::Worker.clear_all
  end

  # Set Sidekiq mode based on metadata
  config.around(:each) do |example|
    if example.metadata[:sidekiq] == :inline
      Sidekiq::Testing.inline! do
        example.run
      end
    elsif example.metadata[:sidekiq] == :disable
      Sidekiq::Testing.disable! do
        example.run
      end
    else
      # Default is fake mode (already set above)
      example.run
    end
  end
end
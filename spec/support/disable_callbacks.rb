# Disable model callbacks that trigger background jobs in tests
RSpec.configure do |config|
  config.before(:suite) do
    # Store original state
    @callbacks_disabled = true
    # Disable Skill embed callback by default
    Skill.skip_callback(:commit, :after, :embed_skill, raise: false) if defined?(Skill)
    # Disable RecruitmentOffice geocoding callback by default
    RecruitmentOffice.skip_callback(:commit, :after, :enqueue_geocoding, raise: false) if defined?(RecruitmentOffice)
  end

  config.after(:suite) do
    # Re-enable callbacks after tests
    Skill.set_callback(:commit, :after, :embed_skill, raise: false) if defined?(Skill)
    RecruitmentOffice.set_callback(:commit, :after, :enqueue_geocoding, raise: false) if defined?(RecruitmentOffice)
  end

  # Allow specific tests to re-enable callbacks
  config.before(:each) do |example|
    if example.metadata[:enable_callbacks]
      Skill.set_callback(:commit, :after, :embed_skill, raise: false) if defined?(Skill)
      RecruitmentOffice.set_callback(:commit, :after, :enqueue_geocoding, raise: false) if defined?(RecruitmentOffice)
    end
  end

  config.after(:each) do |example|
    if example.metadata[:enable_callbacks]
      Skill.skip_callback(:commit, :after, :embed_skill, raise: false) if defined?(Skill)
      RecruitmentOffice.skip_callback(:commit, :after, :enqueue_geocoding, raise: false) if defined?(RecruitmentOffice)
    end
  end
end
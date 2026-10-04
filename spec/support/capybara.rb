require 'capybara/rspec'
require 'capybara/playwright'

# Register Playwright driver
Capybara.register_driver(:playwright) do |app|
  Capybara::Playwright::Driver.new(app,
    browser_type: :chromium,
    headless: true
  )
end

# Use rack_test by default (fast, no JS)
Capybara.default_driver = :rack_test

# For JS tests, use Playwright with headless chromium
Capybara.javascript_driver = :playwright

# Configure server
Capybara.server = :puma, { silent: true }

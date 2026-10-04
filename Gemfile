source "https://rubygems.org"

ruby "3.4.2"

# Core Rails framework
gem "rails", "~> 8.0.1"

# Database and data management
gem "aasm", "~> 5.5"
gem "discard", "~> 1.4"
gem "jsonb_accessor", "~> 1.4"
gem "neighbor", "~> 0.5.2"
gem "pg", "~> 1.1"
gem "redis", "~> 5.4"
gem "store_model", "~> 4.2"

# Authentication and authorization
gem "devise", "~> 4.9"
gem "devise-i18n", "~> 1.12"
gem "pretender", "~> 0.6.0"
gem "pundit", "~> 2.5"

# Admin interface
gem "activeadmin", "4.0.0.beta17"
gem "activeadmin_assets"

# Frontend and assets
gem "importmap-rails"
gem "inline_svg", "~> 1.10"
gem "propshaft"
gem "stimulus-rails"
gem "tailwindcss-rails", "~> 4.2.1"
gem "turbo-rails"
gem "view_component", "~> 3.21"

# Forms and UI
gem "active_link_to", "~> 1.0.5"
gem "pagy", "~> 9.3"
gem "simple_form", "~> 5.3"
gem "simple_form-tailwind", "~> 0.1.2"
gem "wicked", "~> 2.0"

# Background jobs and processing
gem "service_actor-rails", "~> 1.0"
gem "sidekiq", "~> 7.3"
gem "sidekiq-batch", "~> 0.2.0"
gem "sidekiq-scheduler", "~> 5.0"
gem "sidekiq-throttled", "~> 1.5"

# File processing and media
gem "cloudinary", "~> 2.3"
gem "mini_magick", "~> 5.2"
gem "pdf-reader", "~> 2.14"
gem "rtesseract", "~> 3.1"
gem "wicked_pdf", "~> 2.8"
gem "wkhtmltopdf-heroku", "3.0.0"

# Localization and geography
gem "geocoder", "~> 1.8"
gem "i18n_data", "~> 1.1"
gem "rails-i18n", "~> 8.0"

# Utilities
gem "bootsnap", require: false
gem "icalendar", "~> 2.10"
gem "jbuilder"
gem "kramdown", "~> 2.5"
gem "reverse_markdown", "~> 3.0"
gem "puma", ">= 5.0"
gem "thruster", require: false # Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]

group :development, :test do
  gem "brakeman", require: false
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "dotenv-rails"
  gem "letter_opener"
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rails-omakase", require: false # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]

  # Testing
  gem "rspec-rails", "~> 7.1"
  gem "factory_bot_rails", "~> 6.4"
  gem "shoulda-matchers", "~> 6.0"
  gem "faker", "~> 3.5"
  gem "database_cleaner-active_record", "~> 2.2"
end

group :test do
  # Code coverage
  gem "simplecov", require: false
  gem "simplecov-console", require: false

  # Mocking HTTP requests
  gem "webmock"

  # Controller testing
  gem "rails-controller-testing"

  # Feature testing
  gem "capybara"
  gem "capybara-playwright-driver"
end

group :development do
  gem "claude-on-rails"
  gem "rails-erd"
  gem "web-console"
end

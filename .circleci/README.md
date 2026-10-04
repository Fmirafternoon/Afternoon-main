# CircleCI Configuration

## Overview

This project uses CircleCI for continuous integration. The configuration includes:
- PostgreSQL database
- Redis for ActionCable and Sidekiq
- RSpec test suite with coverage

## Environment Variables

### Required in CI

The following environment variables are set in the CircleCI config:

1. **Database**
   - `PGHOST`: localhost
   - `PGUSER`: postgres

2. **Redis**
   - `REDIS_URL`: redis://localhost:6379/1

3. **Email** (test environment uses test adapter, no real SMTP needed)
   - `SMTP_HOST`: localhost
   - `SMTP_USERNAME`: test
   - `SMTP_PASSWORD`: test
   - `FROM`: test@cineplanner.test

4. **Monitoring**
   - `SENTRY_DSN`: "" (disabled in tests)

5. **Rails**
   - `RAILS_ENV`: test
   - `CI`: true
   - `COVERAGE`: true

6. **Cloudinary**
   - `CLOUDINARY_URL`: cloudinary://test:test@test (mocked in tests)

### Email Configuration in Tests

In the test environment:
- ActionMailer uses the `:test` delivery method
- Emails are stored in `ActionMailer::Base.deliveries` array
- No real SMTP connection is made
- The SMTP initializer is skipped in test environment

### Redis in Tests

For tests:
- ActionCable uses the `test` adapter (no Redis needed)
- Sidekiq jobs can be tested with `perform_enqueued_jobs` or `perform_later`

### Cloudinary in Tests

For tests:
- All Cloudinary uploads are mocked via `spec/support/cloudinary.rb`
- Returns fake upload responses without making real API calls
- No actual Cloudinary API key is needed

## Services

The CI environment includes:
1. **PostgreSQL 16.8** - Main database
2. **Redis 7.2** - For caching and background jobs
3. **Ruby 3.3.4** - Application runtime

## Test Artifacts

After each build:
- Test results are stored in `test/reports`
- Coverage reports are stored in `coverage/`

## Running Tests Locally

To replicate the CI environment locally:

```bash
# Start Redis
redis-server

# Set environment variables
export REDIS_URL=redis://localhost:6379/1
export RAILS_ENV=test

# Run tests
bundle exec rspec
```
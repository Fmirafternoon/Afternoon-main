require "sidekiq"
require "sidekiq/throttled"
require "sidekiq/throttled/web"
require "sidekiq-scheduler"


Sidekiq.configure_server do |config|
  config.redis = {
    url: ENV["REDIS_URL"],
    ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
  }

  # Charger le schedule depuis config/schedule.yml au démarrage
  config.on(:startup) do
    schedule_file = Rails.root.join("config/schedule.yml")
    Rails.logger.info "Sidekiq scheduler: Looking for schedule file at #{schedule_file}"

    if File.exist?(schedule_file)
      schedule_config = YAML.load_file(schedule_file)
      Rails.logger.info "Sidekiq scheduler: Loaded schedule with #{schedule_config.keys.size} jobs: #{schedule_config.keys.join(', ')}"

      Sidekiq.schedule = schedule_config
      SidekiqScheduler::Scheduler.instance.reload_schedule!

      Rails.logger.info "Sidekiq scheduler: Schedule reloaded successfully"
    else
      Rails.logger.warn "Sidekiq scheduler: Schedule file not found at #{schedule_file}"
    end
  rescue => e
    Rails.logger.error "Sidekiq scheduler: Error loading schedule: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end

Sidekiq.configure_client do |config|
  config.redis = {
    url: ENV["REDIS_URL"],
    ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
  }
end

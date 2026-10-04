Rails.application.configure do
  config.action_mailer.smtp_settings = {
    address: ENV.fetch("SMTP_HOST"),
    port: 587,
    user_name: ENV.fetch("SMTP_USERNAME"),
    password: ENV.fetch("SMTP_PASSWORD"),
    authentication: :login,
    enable_starttls_auto: true
  }
end

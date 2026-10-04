class CandidateExpirationReminderJob < ApplicationJob
  queue_as :mailers

  def perform
    Candidate.expiring_soon.find_each do |candidate|
      begin
        # Send email FIRST (using deliver_now to catch failures immediately)
        AgentMailer.candidate_expiration_reminder(candidate.id).deliver_now

        # Mark as notified ONLY if email succeeded
        candidate.update_column(:expiration_notified_at, Time.current)

        Rails.logger.info "Expiration reminder sent for candidate #{candidate.id}"
      rescue => e
        Rails.logger.error "Error sending expiration reminder for candidate #{candidate.id}: #{e.message}"
        Sentry.capture_exception(e) if defined?(Sentry)
        # Don't update expiration_notified_at if email failed - candidate will be retried tomorrow
      end
    end
  end
end

class CandidateAutoExpirationJob < ApplicationJob
  queue_as :default

  def perform
    Candidate.expired.find_each do |candidate|
      begin
        if candidate.may_expire_workflow?
          candidate.expire_workflow!
          Rails.logger.info "Candidate #{candidate.id} automatically expired"
        else
          Rails.logger.warn "Candidate #{candidate.id} cannot be expired (invalid state transition)"
        end
      rescue => e
        Rails.logger.error "Error expiring candidate #{candidate.id}: #{e.message}"
        Sentry.capture_exception(e) if defined?(Sentry)
        # Continue with the next candidate
      end
    end
  end
end

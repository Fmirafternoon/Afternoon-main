class WeeklyDigestJob < ApplicationJob
  queue_as :mailers

  def perform
    User.joins(:saved_searches)
        .where(saved_searches: { email_alerts_enabled: true })
        .distinct
        .find_each do |customer|
      begin
        process_customer_digest(customer)
      rescue => e
        Rails.logger.error "Erreur lors du traitement du customer #{customer.id}: #{e.message}"
        # Continue avec le prochain customer
      end
    end
  end

  private

  def process_customer_digest(customer)
    alerts_data = []
    
    customer.saved_searches.with_alerts_enabled.each do |saved_search|
      all_new_candidates = saved_search.find_new_candidates
      next if all_new_candidates.empty?
      
      # Prendre seulement les 5 premiers pour l'email
      candidates_to_send = all_new_candidates.limit(5).to_a
      
      alerts_data << {
        search: saved_search,
        candidates: candidates_to_send,
        total_count: all_new_candidates.count
      }
      
      saved_search.mark_candidates_as_viewed(candidates_to_send)
    end
    
    return if alerts_data.empty?
    
    DigestMailer.weekly_alert(
      customer: customer,
      alerts_data: alerts_data
    ).deliver_later
    
    customer.saved_searches.with_alerts_enabled.update_all(
      last_alert_sent_at: Time.current
    )
  rescue => e
    Rails.logger.error "Erreur digest pour customer #{customer.id}: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
  end
end
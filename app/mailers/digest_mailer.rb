class DigestMailer < ApplicationMailer

  def weekly_alert(customer:, alerts_data:)
    @customer = customer
    @alerts_data = alerts_data
    @total_candidates = alerts_data.sum { |alert| alert[:candidates].count }
    
    # Generate unsubscribe token
    @unsubscribe_token = Rails.application.message_verifier(:unsubscribe).generate({
      customer_id: customer.id,
      action: 'unsubscribe_all',
      expires_at: 30.days.from_now
    })
    
    subject = "📊 #{@total_candidates} #{@total_candidates == 1 ? 'nouveau candidat' : 'nouveaux candidats'} cette semaine"
    
    mail(
      to: customer.email,
      subject: subject
    ) do |format|
      format.html { render 'weekly_alert' }
      format.text { render 'weekly_alert' }
    end
  end
end
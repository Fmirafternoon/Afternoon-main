class AgentMailer < ApplicationMailer
  helper CalendarHelper
  helper ApplicationHelper
  def import_complete(user_id, candidate_ids)
    @candidates = Candidate.where(id: candidate_ids)
    @user = User.find(user_id)
    mail(to: @user.email, subject: "[Afternoon] Import de vos CV terminée")
  end

  def meeting_request(basket_item:)
    @basket_item = basket_item
    @agent = basket_item.agent
    @customer = basket_item.basket.customer
    @candidates = basket_item.candidates

    # Générer et attacher le fichier ICS
    result = Calendar::GenerateInvite.call(basket_item: basket_item)
    attachments['invitation.ics'] = {
      mime_type: 'text/calendar',
      content: result.ics_content
    }

    mail(
      to: @agent.email,
      reply_to: @customer.email,
      subject: "[Afternoon] Nouvelle demande de RDV - #{@candidates.count} candidat(s)"
    )
  end

  def candidate_matched(project_candidate_id)
    @project_candidate = ProjectCandidate.find(project_candidate_id)
    @candidate = @project_candidate.candidate
    @project = @project_candidate.project
    @agent = @candidate.agent

    return unless @agent.present?

    mail(
      to: @agent.email,
      subject: "[Afternoon] #{@candidate.full_name} matche un projet - #{@project.title}"
    )
  end

  def customer_interested(project_candidate)
    @project_candidate = project_candidate
    @candidate = project_candidate.candidate
    @project = project_candidate.project
    @customer = @project.customer
    @agent = @candidate.agent

    return unless @agent.present?

    mail(
      to: @agent.email,
      reply_to: @customer.email,
      subject: "[Afternoon] Client intéressé - #{@candidate.full_name} - #{@project.title}"
    )
  end

  def customer_rejected(project_candidate)
    @project_candidate = project_candidate
    @candidate = project_candidate.candidate
    @project = project_candidate.project
    @customer = @project.customer
    @agent = @candidate.agent

    return unless @agent.present?

    mail(
      to: @agent.email,
      subject: "[Afternoon] Candidat rejeté - #{@candidate.full_name} - #{@project.title}"
    )
  end

  def project_broadcast(agent_id, project_id)
    @agent = User.find(agent_id)
    @project = Project.find(project_id)
    @customer = @project.customer

    mail(
      to: @agent.email,
      reply_to: @customer.email,
      subject: "[Afternoon] Nouveau projet à pourvoir - #{@project.position_name}"
    )
  end

  def candidate_expiration_reminder(candidate_id)
    @candidate = Candidate.find(candidate_id)
    @agent = @candidate.agent
    @days_until_expiration = [(@candidate.expires_at.to_date - Date.current).to_i, 0].max

    # Generate secure tokens for actions (3 days expiration - enough time to take action)
    @extend_token = Rails.application.message_verifier(:candidate_expiration).generate({
      candidate_id: @candidate.id,
      action: 'extend',
      expires_at: 3.days.from_now
    })

    @unpublish_token = Rails.application.message_verifier(:candidate_expiration).generate({
      candidate_id: @candidate.id,
      action: 'unpublish',
      expires_at: 3.days.from_now
    })

    @extend_url = extend_candidate_expiration_url(token: @extend_token)
    @unpublish_url = unpublish_candidate_expiration_url(token: @unpublish_token)

    mail(
      to: @agent.email,
      subject: "[Afternoon] Prolonger ou dépublier #{@candidate.full_name} ?"
    )
  end
end

class Agent::Projects::CandidatesController < Agent::BaseController
  include MarkdownHelper

  before_action :set_project
  before_action :set_project_candidate

  def show
    authorize @project, :show?
  end

  def push_form
    authorize @project, :show?

    unless @project_candidate.matched? && @project_candidate.analysis_ready?
      redirect_to agent_project_path(@project), alert: "Ce candidat ne peut pas être présenté."
      return
    end

    if @project_candidate.questions_required?
      @project_candidate.generate_questions!
      redirect_to questions_agent_project_candidate_path(@project, @project_candidate)
      return
    end

    render layout: false
  end

  def push
    authorize @project, :show?

    unless @project_candidate.matched? && @project_candidate.analysis_ready?
      redirect_to agent_project_path(@project), alert: "Ce candidat ne peut pas être présenté."
      return
    end

    if @project_candidate.questions_required?
      @project_candidate.generate_questions!
      redirect_to questions_agent_project_candidate_path(@project, @project_candidate),
                  alert: "Merci de répondre aux questions avant de présenter le candidat."
      return
    end

    # Sauvegarder l'analyse éditée par l'agent et présenter
    push_data = params[:push]
    @project_candidate.update!(
      status: :pushed,
      pushed_at: Time.current,
      agent_analysis: {
        summary: html_to_md(push_data[:summary]),
        strengths: parse_html_list(push_data[:strengths]),
        attention_points: parse_html_list(push_data[:attention_points])
      }
    )

    CustomerMailer.candidate_pushed(@project_candidate).deliver_later
    redirect_to agent_project_path(@project), notice: "Candidat présenté au client."
  end

  def cancel
    authorize @project, :show?

    if @project_candidate.matched? || @project_candidate.pushed?
      @project_candidate.update!(status: :rejected)
      redirect_to agent_project_path(@project), notice: "Candidat annulé."
    else
      redirect_to agent_project_path(@project), alert: "Ce candidat ne peut pas etre annulé."
    end
  end

  def questions
    authorize @project, :show?

    @project_candidate.generate_questions!
    @questions = @project_candidate.project_candidate_questions.order(:id)
  end

  def submit_questions
    authorize @project, :show?

    (params[:answers] || {}).each do |id, answer|
      question = @project_candidate.project_candidate_questions.find_by(id: id)
      question&.update(answer: answer)
    end

    if @project_candidate.pending_questions?
      redirect_to questions_agent_project_candidate_path(@project, @project_candidate),
                  alert: "Merci de répondre à toutes les questions avant de présenter le candidat."
    else
      redirect_to agent_project_candidate_path(@project, @project_candidate),
                  notice: "Réponses enregistrées. Vous pouvez maintenant présenter le candidat."
    end
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_project_candidate
    @project_candidate = @project.project_candidates.find(params[:id])
  end

  def parse_html_list(html)
    return [] if html.blank?
    # Extraire le contenu de chaque <li> et convertir en markdown
    doc = Nokogiri::HTML.fragment(html)
    doc.css("li").map do |li|
      html_to_md(li.inner_html).strip
    end.reject(&:blank?)
  end
end

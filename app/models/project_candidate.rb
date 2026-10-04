class ProjectCandidate < ApplicationRecord
  belongs_to :project
  belongs_to :candidate

  has_many :project_candidate_questions, dependent: :destroy

  enum :status, {
    pending: -1,          # En attente d'analyse LLM
    matched: 0,           # Candidat matché et analysé - visible par l'agent
    validated: 1,         # Validé par l'agent
    pushed: 2,            # Présenté au client
    interested: 3,        # Client intéressé
    rejected: 4,          # Client a rejeté
    hired: 5              # Embauché
  }

  scope :for_customer, -> { where(status: [:pushed, :interested, :rejected, :hired]) }
  scope :for_agent, -> { where.not(status: :pending) }
  scope :new_for_customer, -> { pushed.where(viewed_at: nil) }
  scope :ordered, -> { order(created_at: :desc) }

  def anonymized_number
    candidate.public_token
  end

  def initials
    candidate.first_name.first.upcase + candidate.last_name.first.upcase rescue "??"
  end

  # Accesseurs pour l'analyse - priorité à agent_analysis si présent
  def strengths
    (agent_analysis["strengths"].presence || llm_analysis["strengths"]) || []
  end

  def attention_points
    (agent_analysis["attention_points"].presence || llm_analysis["attention_points"]) || []
  end

  def summary
    agent_analysis["summary"].presence || llm_analysis["summary"]
  end

  # Accesseurs pour les valeurs LLM originales (pour pré-remplir le formulaire)
  def llm_strengths
    llm_analysis["strengths"] || []
  end

  def llm_attention_points
    llm_analysis["attention_points"] || []
  end

  def llm_summary
    llm_analysis["summary"]
  end

  def analysis_ready?
    llm_analysis["summary"].present?
  end

  def mark_as_viewed!
    update!(viewed_at: Time.current) if viewed_at.nil?
  end

  def express_interest!(message: nil)
    update!(
      status: :interested,
      interest_expressed_at: Time.current,
      interest_message: message
    )
  end

  def reject!(reason: nil)
    update!(
      status: :rejected,
      interest_message: reason
    )
  end

  # --- Questions conditionnelles avant présentation (B4-B6) ---
  CV_OUTDATED_AFTER = 6.months

  # Compétences OBLIGATOIRES du projet que le candidat n'a pas
  def missing_required_skills
    required_ids = project.project_skills.where(required: true).pluck(:skill_id)
    candidate_ids = candidate.candidate_skills.pluck(:skill_id)
    Skill.where(id: required_ids - candidate_ids)
  end

  # CV jamais daté, ou trop ancien
  def cv_outdated?
    candidate.last_updated_at.blank? || candidate.last_updated_at < CV_OUTDATED_AFTER.ago.to_date
  end

  # Le profil justifie-t-il de poser des questions ?
  def needs_questions?
    missing_required_skills.any? || cv_outdated?
  end

  # Crée les questions (par règles simples) - idempotent
  def generate_questions!
    return if project_candidate_questions.exists?

    missing_required_skills.each do |skill|
      project_candidate_questions.create!(
        kind: "missing_skill",
        question: "Le candidat maîtrise-t-il la compétence « #{skill.name} » (obligatoire pour ce poste) ? Si oui, précisez son niveau et son expérience."
      )
    end

    if cv_outdated?
      cv_question =
        if candidate.last_updated_at
          "Le CV du candidat date du #{candidate.last_updated_at.strftime('%d/%m/%Y')}. Les informations (poste, disponibilité, compétences) sont-elles toujours d'actualité ?"
        else
          "La date de dernière mise à jour du CV du candidat est inconnue. Les informations (poste, disponibilité, compétences) sont-elles à jour ?"
        end
      project_candidate_questions.create!(kind: "outdated_cv", question: cv_question)
    end
  end

  # Reste-t-il des questions sans réponse ?
  def pending_questions?
    project_candidate_questions.unanswered.exists?
  end

  # Faut-il répondre à des questions avant de pouvoir présenter ce candidat ?
  def questions_required?
    if project_candidate_questions.exists?
      pending_questions?          # déjà générées : bloqué tant qu'il en reste sans réponse
    else
      needs_questions?            # pas encore générées : bloqué si le profil le nécessite
    end
  end

  # Les questions déjà répondues (jointes à la présentation client)
  def answered_questions
    project_candidate_questions.where.not(answer: [nil, ""]).order(:id)
  end

  # Ransack whitelist for ActiveAdmin
  def self.ransackable_attributes(auth_object = nil)
    %w[id status created_at viewed_at interest_expressed_at project_id candidate_id]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[project candidate]
  end
end

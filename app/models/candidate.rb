class Candidate < ApplicationRecord
  WIZARD_STEPS = %i[personal_info motivations skills employments educations trainings referrals availability comission]

  # Champs pris en compte dans le taux de complétion du profil (total : 100)
  COMPLETION_FIELDS = {
    position: { weight: 10, label: "Poste recherché", filled: ->(c) { c[:position].present? } },
    location: { weight: 10, label: "Localisation", filled: ->(c) { c.location_id.present? } },
    phone_number: { weight: 5, label: "Téléphone", filled: ->(c) { c.phone_number.present? } },
    email: { weight: 5, label: "Email", filled: ->(c) { c.email.present? } },
    resume: { weight: 5, label: "CV", filled: ->(c) { c.resume_url.present? } },
    employments: { weight: 20, label: "Expérience professionnelle", filled: ->(c) { c.employments.exists? } },
    skills: { weight: 20, label: "Compétences", filled: ->(c) { c.candidate_skills.exists? } },
    languages: { weight: 5, label: "Langues", filled: ->(c) { c.candidate_languages.exists? } },
    degrees: { weight: 5, label: "Diplômes / Certifications", filled: ->(c) { c.educations.exists? || c.trainings.exists? } },
    availability: { weight: 5, label: "Disponibilité", filled: ->(c) { c.availability_notice.present? } },
    salary: { weight: 5, label: "Prétentions salariales", filled: ->(c) { c.salary_expectation.present? } }
  }.freeze

  include Discard::Model
  include Candidate::ImportStateMachine
  include Candidate::PublicationStateMachine

  belongs_to :agent, class_name: "User", foreign_key: "agent_id"
  belongs_to :location, optional: true

  has_many :candidate_skills, dependent: :destroy
  has_many :skills, through: :candidate_skills
  has_many :candidate_languages, dependent: :destroy
  has_many :employments, dependent: :destroy
  has_many :educations, dependent: :destroy
  has_many :trainings, dependent: :destroy
  has_many :referrals, dependent: :destroy
  has_many :candidate_mobilities, dependent: :destroy
  has_many :locations, through: :candidate_mobilities
  has_many :candidate_sectors, dependent: :destroy
  has_many :sectors, through: :candidate_sectors

  has_many :red_flags, dependent: :destroy

  has_many :candidate_documents, dependent: :destroy

  jsonb_accessor :resume_summary,
    skills: :string,
    accomplishments: :string,
    management: :string,
    specializations: [:string, array: true, default: []],
    security_qualifications: [:string, array: true, default: []],
    tools_and_technologies: [:string, array: true, default: []]

  enum :import_status, { # analyse status
    uploading: "uploading",
    pending: "pending",
    completed: "completed",
    failed: "failed"
  }, default: nil, prefix: :import

  enum :publication_status, {
    draft: "draft",
    pending: "pending",
    published: "published"
  }, default: :draft

  enum :gender, {
    male: "male",
    female: "female"
  }

  enum :contract_type, {
    cdi: "cdi",
    cdd: "cdd",
    interim: "interim"
  }, default: :cdi

  enum :availability_notice, {
    immediate: "immediate",
    two_to_three_weeks: "2_to_3_weeks",
    four_to_six_weeks: "4_to_6_weeks",
    two_months: "2_months",
    three_months: "3_months",
    four_months_plus: "4_months_plus"
  }, default: :immediate

  validates :position, presence: true, if: :published?

  before_create :generate_public_token
  after_commit :enqueue_project_matching, if: :just_published?
  # Se déclenche aussi via les `belongs_to touch: true` des modèles associés
  # (employments, candidate_skills, etc.)
  after_commit :recalculate_completion_percentage!, on: [:create, :update]

  def archived?
    discarded?
  end

  def self.archived
    with_discarded.discarded
  end

  def output
    as_json(include: [
      :skills,
      :educations,
      :employments,
      :trainings,
      :referrals,
      :locations,
      :candidate_languages
    ])
  end

  def skill_names
    skills.pluck(:name)
  end

  def city
    location&.city
  end

  def age
    return nil if birth_year.nil?

    Date.today.year - birth_year
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def initials
    [first_name, last_name].compact.map { |n| n[0]&.upcase }.compact.join
  end

  def publishable?
    !archived? && validation_errors.empty?
  end

  def unanswered_red_flags_count
   red_flags.where(answer: nil).count
  end

  # Normalisé sur la somme des poids : un profil complet vaut toujours 100 %,
  # même si les poids de COMPLETION_FIELDS évoluent
  def calculate_completion_percentage
    total = COMPLETION_FIELDS.values.sum { |field| field[:weight] }
    filled = COMPLETION_FIELDS.values.sum { |field| field[:filled].call(self) ? field[:weight] : 0 }
    (filled * 100.0 / total).round
  end

  def missing_completion_fields
    COMPLETION_FIELDS.values.reject { |field| field[:filled].call(self) }.map { |field| field[:label] }
  end

  # update_column ne déclenche aucun callback : pas de boucle avec l'after_commit
  def recalculate_completion_percentage!
    computed = calculate_completion_percentage
    update_column(:completion_percentage, computed) if completion_percentage != computed
  end
  
  
  def position
    super || resume_file_name
  end

  def validation_errors
    @validation_errors ||= WIZARD_STEPS.each_with_object({}) do |step, errors|
      form_class = "Candidate::#{step.to_s.camelize}Form".constantize

      # Si GLOBAL_VALIDATION n'est pas défini, on valide tout
      # Si c'est un tableau, on ne valide que les validations spécifiées
      # Si c'est false, on skip complètement
      next if form_class.const_defined?(:GLOBAL_VALIDATION) && form_class::GLOBAL_VALIDATION == false

      form = form_class.new(
        form_class.new(id: id)
          .attributes.keys
          .select { |attr| respond_to?(attr) }
          .map { |attr| [attr, send(attr)] }
          .to_h
      )

      if form_class.const_defined?(:GLOBAL_VALIDATION) && form_class::GLOBAL_VALIDATION.is_a?(Array)
        # On ne valide que les validations spécifiées
        form_class::GLOBAL_VALIDATION.each do |validation|
          form.send(validation)
        end
      else
        # On valide tout
        form.valid?
      end

      unless form.errors.empty?
        errors[step] = form.errors.full_messages
      end
    end
  end

  def self.search_by_similarity(query, min_similarity: 0.7, limit: 20)
    # Créer l'embedding de la query
    result = Embedding::Create.call(text: [query])

    # Rechercher avec seuil de similarité
    where.not(job_title_embedding: nil)
      .where("1 - (job_title_embedding <=> ARRAY[?]::vector) >= ?",
             result.embedding.join(","), min_similarity)
      .order(Arel.sql("job_title_embedding <=> ARRAY[#{result.embedding.join(',')}]::vector"))
      .limit(limit)
  end

  def self.search_by_similarity_with_score(query, min_similarity: 0.7, limit: 20)
    result = Embedding::Create.call(text: [query])

    select("candidates.*,
            (1 - (job_title_embedding <=> ARRAY[#{result.embedding.join(',')}]::vector)) AS similarity_score")
      .where.not(job_title_embedding: nil)
      .where("1 - (job_title_embedding <=> ARRAY[#{result.embedding.join(',')}]::vector) >= ?", min_similarity)
      .order(Arel.sql("job_title_embedding <=> ARRAY[#{result.embedding.join(',')}]::vector"))
      .limit(limit)
  end

  scope :near_location, ->(lat, lng, radius_km = 50) {
    # Candidates within radius based on their location or mobility locations
    nearby_location_ids = Location.near([lat, lng], radius_km, units: :km).reorder(nil).pluck(:id)

    joins(:candidate_mobilities).where(location_id: nearby_location_ids)
      .or(joins(:candidate_mobilities).where(candidate_mobilities: { location_id: nearby_location_ids }))
      .distinct
  }

  # Expiration scopes
  # Candidats qui expirent dans moins de 3 jours et qui n'ont pas encore été notifiés
  scope :expiring_soon, -> {
    published
      .where('expires_at <= ? AND expires_at > ? AND expiration_notified_at IS NULL',
             3.days.from_now, Time.current)
  }

  # Candidats expirés : notifiés ET expirés, OU expirés depuis plus de 7 jours (fallback si notification échouée)
  scope :expired, -> {
    published
      .where('(expires_at <= ? AND expiration_notified_at IS NOT NULL) OR expires_at <= ?',
             Time.current, 7.days.ago)
  }

  def extend_publication!
    raise ActiveRecord::RecordInvalid, "Candidate must be published" unless published?
    update!(expires_at: 14.days.from_now, expiration_notified_at: nil)
  end

  private

  def generate_public_token
    self.public_token = SecureRandom.alphanumeric(6).upcase
  end

  def just_published?
    saved_change_to_publication_status? && published?
  end

  def enqueue_project_matching
    Candidate::MatchProjectsJob.perform_async(id)
  end
end

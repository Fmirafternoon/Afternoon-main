class Candidate::SkillsForm < BaseForm
  self.model_class = CandidateSkill

  attribute :id, :integer
  attribute :skill, :string
  attribute :language_code, :string
  attribute :language_level, :string

  attribute :sector_id, :integer

  validates :skill, presence: true, on: :add_skill
  validate :at_least_one_skill, if: -> {  sector_id.blank? && skill.blank? && language_code.blank? && language_level.blank? }

  validates :language_code, presence: true, if: -> { language_code.present? || language_level.present? }

  validates :sector_id, presence: true, on: :add_sector
  validate :at_least_one_sector, if: -> { sector_id.blank? && skill.blank? && language_code.blank? && language_level.blank? }

  def initialize(attributes = {})
    @candidate = Candidate.find(attributes.with_indifferent_access.dig(:id))
    super(attributes)
  end

  def languages_list
    priority_languages = {
      "fr" => "Français",
      "en" => "Anglais",
      "es" => "Castillan (Espagnol)",
      "de" => "Allemand",
      "ar" => "Arabe",
      "pt" => "Portugais",
      "bg" => "Bulgare",
      "it" => "Italien",
      "nl" => "Néerlandais",
      "pl" => "Polonais",
      "ro" => "Roumain",
      "ru" => "Russe"
    }

    all_languages = I18nData.languages(:fr)

    priority_languages.map { |code, name| [name, code] } +
      (all_languages.reject { |code, _| priority_languages.keys.include?(code.downcase) }
                    .map { |code, name| [name.capitalize, code.downcase] }
                    .sort_by { |name, _| name })
  end

  def language_levels_list
    %w[A1 A2 B1 B2 C1 C2]
  end

  def persist!
    valid?
  end

  def persist_language!
    return false unless valid?(:add_language)

    @candidate.candidate_languages.create(code: language_code, level: language_level)

    self.id = @candidate.id
  end

  def persist_skill!
    return false unless valid?(:add_skill)


    skill_record = Skill.find_or_create_by(slug: skill.parameterize) do |s|
      s.name = skill
    end

    unless @candidate.skills.include?(skill_record)
      @candidate.skills << skill_record
    end

    self.id = @candidate.id
  end

  def persist_sector!
    return false unless valid?(:add_sector)

    @candidate.sectors << Sector.find(sector_id)

    self.id = @candidate.id
  end

  private

  def at_least_one_skill
    if @candidate.skills.empty?
      errors.add(:skill, :at_least_one_skill)
    end
  end

  def at_least_one_sector
    if @candidate.sectors.empty?
      errors.add(:sector_id, :at_least_one_sector)
    end
  end
end

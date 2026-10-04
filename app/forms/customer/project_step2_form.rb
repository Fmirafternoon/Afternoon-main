class Customer::ProjectStep2Form < BaseForm
  self.model_class = Project

  attribute :skills, default: -> { [] }
  attribute :min_experience_years, :integer
  attribute :desired_availability, :string

  validates :skills, presence: true
  validates :desired_availability, presence: true

  def initialize(attributes = {}, project:)
    @project = project
    super(attributes)
    load_from_project if attributes.blank?
  end

  attr_reader :project

  def skills=(value)
    normalized = Array(value).filter_map do |attrs|
      attrs = attrs.to_h.stringify_keys
      name = attrs["name"].to_s.strip
      next if name.blank?

      {
        "name" => name,
        "required" => ActiveModel::Type::Boolean.new.cast(attrs["required"]),
        "seniority" => attrs["seniority"].presence
      }
    end
    super(normalized)
  end

  private

  def load_from_project
    self.skills = project.project_skills.includes(:skill).map do |project_skill|
      { "name" => project_skill.skill.name, "required" => project_skill.required, "seniority" => project_skill.seniority }
    end
    self.min_experience_years = project.min_experience_years
    self.desired_availability = project.desired_availability
  end

  def persist!
    project.assign_attributes(
      min_experience_years: min_experience_years,
      desired_availability: desired_availability
    )

    ActiveRecord::Base.transaction do
      project.save!
      sync_skills!
    end
  end

  def sync_skills!
    project.project_skills.destroy_all
    skills.each do |attrs|
      skill = Skill.create_or_find_by_name(attrs["name"])
      project.project_skills.create!(skill: skill, required: attrs["required"], seniority: attrs["seniority"])
    end
  end
end

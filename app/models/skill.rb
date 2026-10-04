class Skill < ApplicationRecord
  has_many :candidate_skills
  has_many :candidates, through: :candidate_skills

  after_create_commit :embed_skill

  def self.ransackable_attributes(auth_object = nil)
    %w[name slug]
  end

  before_validation :set_slug

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: {
    case_sensitive: false,
    message: "a déjà été ajoutée (même si orthographiée différemment)"
  }

  def self.create_or_find_by_name(name)
    slug = name.to_s.parameterize
    find_by(slug:) || create!(name: name)
  end

  private

  def set_slug
    self.slug = name.to_s.parameterize if name.present?
  end

  def embed_skill
    Skill::EmbedJob.perform_async(id)
  end
end

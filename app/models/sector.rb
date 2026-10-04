class Sector < ApplicationRecord
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :set_slug

  def to_s
    name
  end

  private

  def set_slug
    self.slug = name.to_s.parameterize if slug.blank?
  end
end

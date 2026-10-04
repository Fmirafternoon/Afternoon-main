class CandidateLanguage < ApplicationRecord
  belongs_to :candidate, touch: true

  validates :code, presence: true
  validates :level, inclusion: { in: %w[A1 A2 B1 B2 C1 C2] }, allow_blank: true
  validate :validate_language_code
  validates :code, uniqueness: { scope: :candidate_id, case_sensitive: false }

  def name
    I18nData.languages(:fr)[code.upcase]
  end

  private

  def validate_language_code
    return if code.blank?
    
    valid_codes = I18nData.languages(:fr).keys
    unless valid_codes.map(&:downcase).include?(code.downcase)
      errors.add(:code, "n'est pas inclus(e) dans la liste")
    end
  end
end

class Employment < ApplicationRecord
  belongs_to :candidate, touch: true

  before_validation :set_duration_in_months

  default_scope { order(from_year: :desc, from_month: :desc) }

  def from_date
    @from_date ||= format_date(from_month, from_year)
  end

  def to_date
    @to_date ||= format_date(to_month, to_year)
  end

  private

  def set_duration_in_months
    if from_year.present? && from_month.present? && to_year.present? && to_month.present?
      self.duration_in_months = (to_year - from_year) * 12 + (to_month - from_month)
    else
      self.duration_in_months = nil
    end
  end

  def format_date(month, year)
    return nil unless month.present? && year.present?

    format("%02d/%04d", month.to_i, year.to_i)
  end
end

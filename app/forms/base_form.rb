class BaseForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations
  include ActiveModel::Translation

  class_attribute :model_class

  def save
    return false unless valid?
    persist!
    true
  end

  # Convertir from_date en from_month et from_year avant la validation
  def from_date=(value)
    if value.present?
      month, year = parse_date(value)
      self.from_month = month if month
      self.from_year = year if year
    end
    @from_date = value
  end

  # Convertir to_date en to_month et to_year avant la validation
  def to_date=(value)
    if value.present?
      month, year = parse_date(value)
      self.to_month = month if month
      self.to_year = year if year
    end
    @to_date = value
  end

  # Accesseurs pour les attributs virtuels
  def from_date
    @from_date || format_date(from_month, from_year)
  end

  def to_date
    @to_date || format_date(to_month, to_year)
  end

  private

  def persist!
    raise NotImplementedError, "#{self.class} doit implémenter la méthode #persist!"
  end

  def assign_to(model)
    model.assign_attributes(attributes)
  end

  # def self.human_attribute_name(attr, options = {})
  #   model_class ? model_class.human_attribute_name(attr, options) : super
  # end

  # Helper pour formatter MM/AAAA
  def format_date(month, year)
    return nil unless month.present? && year.present?
    format("%02d/%04d", month.to_i, year.to_i)
  end

  # Helper pour parser MM/AAAA
  def parse_date(date_string)
    return [nil, nil] unless date_string.present?

    if date_string =~ /^(\d{1,2})\/(\d{4})$/
      [$1.to_i, $2.to_i]
    else
      [nil, nil]
    end
  end
end

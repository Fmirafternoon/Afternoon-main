class Customer::PositionsForm < BaseForm
  self.model_class = CompanyPosition

  attribute :title, :string

  validates :title, presence: true

  def initialize(attributes = {})
    super(attributes)
  end

  private

  def persist!
    current_user.company.positions.create(title: title)
  end

  def current_user
    Current.user
  end
end

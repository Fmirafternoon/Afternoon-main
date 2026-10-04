class Customer::ProjectStep3Form < BaseForm
  self.model_class = Project

  attribute :broadcast_enabled, :boolean, default: false

  def initialize(attributes = {}, project:)
    @project = project
    super(attributes)
    load_from_project if attributes.blank?
  end

  attr_reader :project

  private

  def load_from_project
    self.broadcast_enabled = project.broadcast_enabled
  end

  def persist!
    project.update!(broadcast_enabled: broadcast_enabled)
    project.active!
  end
end

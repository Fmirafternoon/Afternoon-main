class BadgeComponent < ViewComponent::Base
  def initialize(label:, classes:, svg: nil)
    @label = label
    @classes = classes
    @svg = svg
  end

  attr_reader :label, :classes, :svg

  def padding
    svg.present? ? 'pr-3 pl-2' : 'px-2'
  end
end

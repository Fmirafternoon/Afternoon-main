class SavedSearchItemComponent < ViewComponent::Base
  include Turbo::FramesHelper

  def initialize(saved_search:, active: false)
    @saved_search = saved_search
    @active = active
  end

  private

  attr_reader :saved_search, :active

  def container_classes
    base_classes = [
      "relative",
      "group",
      "flex",
      "border",
      "first:rounded-t-md",
      "last:rounded-b-md",
      "focus-within:relative",
      "focus-within:z-10",
      "transition-colors"
    ]

    if active
      base_classes << "z-10" # Pour que la bordure soit au-dessus
      base_classes << "bg-white"
      base_classes << "border-black"
    else
      base_classes << "bg-gray-50"
      base_classes << "border-gray-200"
    end

    base_classes.join(" ")
  end
end

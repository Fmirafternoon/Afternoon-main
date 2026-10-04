# frozen_string_literal: true

class SectorCardComponent < ViewComponent::Base
  def initialize(title:, image_url:, description: nil, button_text: nil, button_link: nil)
    @title = title
    @image_url = image_url
    @description = description
    @button_text = button_text
    @button_link = button_link
  end

  def with_action?
    @description.present? && @button_text.present? && @button_link.present?
  end

  def css_classes
    classes = ["relative rounded-[18px] overflow-hidden shadow-md h-[320px] md:h-[480px]"]
    classes << "group" if with_action?
    classes.join(" ")
  end
end

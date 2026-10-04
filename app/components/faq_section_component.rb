# frozen_string_literal: true

class FaqSectionComponent < ViewComponent::Base
  attr_reader :title

  renders_many :questions, "FaqQuestionComponent"

  erb_template <<~ERB
    <% questions.each do |question| %>
      <%= question %>
    <% end %>
  ERB
end

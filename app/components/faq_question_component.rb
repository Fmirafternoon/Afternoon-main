# frozen_string_literal: true

class FaqQuestionComponent < ViewComponent::Base
  def initialize(title:, answer:, open: false)
    @title = title
    @answer = answer
    @open = open
  end

  attr_reader :title, :answer, :open, :id
end

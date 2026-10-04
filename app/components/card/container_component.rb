# frozen_string_literal: true

class Card::ContainerComponent < ViewComponent::Base
  renders_many :cards, 'CardComponent'
  renders_many :titles, 'Card::TitleComponent'
end

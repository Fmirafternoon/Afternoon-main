# frozen_string_literal: true

# Barre de progression horizontale du taux de complétion du profil.
# Affichée uniquement pour les profils publiés.
class Candidate::CompletionBarComponent < ViewComponent::Base
  def initialize(candidate:)
    @candidate = candidate
  end

  attr_reader :candidate

  def render?
    candidate.published?
  end

  def percentage
    candidate.completion_percentage
  end

  def color_class
    if percentage < 40
      "bg-red-500"
    elsif percentage < 70
      "bg-orange-400"
    else
      "bg-success-500"
    end
  end
end

# frozen_string_literal: true

# Jauge circulaire (donut) du taux de complétion du profil, avec le pourcentage
# au centre et un tooltip listant les champs manquants au survol.
# Affichée uniquement pour les profils publiés.
class Candidate::CompletionDonutComponent < ViewComponent::Base
  RADIUS = 45
  CIRCUMFERENCE = (2 * Math::PI * RADIUS).round(2)

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

  def stroke_dashoffset
    (CIRCUMFERENCE * (1 - percentage / 100.0)).round(2)
  end

  def color_class
    if percentage < 40
      "text-red-500"
    elsif percentage < 70
      "text-orange-400"
    else
      "text-success-500"
    end
  end

  def tooltip_content
    missing = candidate.missing_completion_fields
    return "Profil complet, bravo !" if missing.empty?

    items = missing.map { |label| "<li>#{ERB::Util.html_escape(label)}</li>" }.join
    "<div class='font-semibold mb-1'>Champs manquants :</div><ul class='list-disc pl-4'>#{items}</ul>"
  end
end

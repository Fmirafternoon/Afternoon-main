module ApplicationHelper
  include Pagy::Frontend
  include MarkdownHelper

  def format_indeterminate(value)
    if value == true
      "Oui"
    elsif value == false
      "Non"
    else
      "Non spécifié"
    end
  end

  def datetime(datetime)
    datetime&.strftime("%d/%m/%Y à %H:%M")
  end

  # Renders inline markdown (bold only) for simple text
  def markdown_inline(text)
    return "" if text.blank?
    text.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>').html_safe
  end
end

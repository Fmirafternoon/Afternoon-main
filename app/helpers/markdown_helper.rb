require "reverse_markdown"

module MarkdownHelper
  # Markdown → HTML (for Trix editor display)
  def md_to_html(text)
    return "" if text.blank?
    Kramdown::Document.new(text.to_s).to_html.strip
  end

  # HTML → Markdown (for storage)
  def html_to_md(html)
    return "" if html.blank?
    ReverseMarkdown.convert(html.to_s, unknown_tags: :bypass).strip
  end

  # Array of markdown strings → HTML list (for Trix editor)
  def md_array_to_html_list(items)
    return "" if items.blank?
    items_html = items.map { |item| "<li>#{md_to_html(item)}</li>" }.join
    "<ul>#{items_html}</ul>"
  end
end

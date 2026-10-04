# frozen_string_literal: true

class SectorCardComponentPreview < ViewComponent::Preview
  def default
    render(SectorCardComponent.new(
      title: "BTP",
      image_url: "https://images.unsplash.com/photo-1504307651254-35680f356dfd?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80",
    ))
  end

  def with_action
    render(SectorCardComponent.new(
      title: "BTP",
      image_url: "https://images.unsplash.com/photo-1504307651254-35680f356dfd?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80",
      description: "Recruter un collaborateur dans ce secteur",
      button_text: "En discuter"
    ))
  end

  def transport
    render(SectorCardComponent.new(
      title: "Transport",
      image_url: "https://images.unsplash.com/photo-1494412574643-ff11b0a5c1c3?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80"
    ))
  end

  def industrie
    render(SectorCardComponent.new(
      title: "Industrie",
      image_url: "https://images.unsplash.com/photo-1516937941344-00b4e0337589?ixlib=rb-1.2.1&auto=format&fit=crop&w=800&q=80"
    ))
  end
end

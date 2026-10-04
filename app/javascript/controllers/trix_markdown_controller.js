import { Controller } from "@hotwired/stimulus"
import "trix"

export default class extends Controller {
  connect() {
    // Attendre que Trix soit prêt
    this.element.addEventListener("trix-initialize", this.customize.bind(this))
  }

  customize(event) {
    const toolbar = event.target.toolbarElement
    if (!toolbar) return

    // Cacher les boutons qu'on ne veut pas (garder bold, italic, bullet list)
    const hideSelectors = [
      "[data-trix-attribute=strike]",
      "[data-trix-attribute=href]",
      "[data-trix-attribute=heading1]",
      "[data-trix-attribute=quote]",
      "[data-trix-attribute=code]",
      "[data-trix-attribute=number]",
      "[data-trix-action=decreaseNestingLevel]",
      "[data-trix-action=increaseNestingLevel]",
      "[data-trix-action=attachFiles]",
      ".trix-button-group--file-tools",
      ".trix-button-group--history-tools"
    ]

    hideSelectors.forEach(selector => {
      toolbar.querySelectorAll(selector).forEach(el => {
        el.style.display = "none"
      })
    })
  }
}

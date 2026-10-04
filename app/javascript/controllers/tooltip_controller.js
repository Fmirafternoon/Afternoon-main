import { Controller } from "@hotwired/stimulus"
import tippy from "tippy.js"

// Affiche un tooltip au survol de l'élément.
//
// Usage :
//   <div data-controller="tooltip"
//        data-tooltip-content-value="Contenu (HTML autorisé)"
//        data-tooltip-placement-value="bottom">
export default class extends Controller {
  static values = {
    content: String,
    placement: { type: String, default: "top" }
  }

  connect() {
    this.tippy = tippy(this.element, {
      content: this.contentValue,
      allowHTML: true,
      placement: this.placementValue
    })
  }

  disconnect() {
    if (this.tippy) {
      this.tippy.destroy()
      this.tippy = null
    }
  }
}

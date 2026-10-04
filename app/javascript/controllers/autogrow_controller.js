import { Controller } from "@hotwired/stimulus"

// Usage: data-controller="autogrow"
export default class extends Controller {
  connect() {
    this.autogrow()
    this.element.addEventListener('input', this.autogrow.bind(this))
  }

  autogrow() {
    this.element.style.height = 'auto'
    this.element.style.height = this.element.scrollHeight + 2 + 'px'
  }
}
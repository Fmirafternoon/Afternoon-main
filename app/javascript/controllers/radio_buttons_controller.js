import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "input"]

  select(event) {
    // Remove active from all labels
    this.labelTargets.forEach(label => label.classList.remove("active"))

    // Add active to clicked label
    event.currentTarget.classList.add("active")
  }
}

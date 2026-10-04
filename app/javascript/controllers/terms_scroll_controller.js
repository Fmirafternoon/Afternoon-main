import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "submit"]

  connect() {
    this.checkScroll()
  }

  scroll() {
    this.checkScroll()
  }

  checkScroll() {
    const container = this.containerTarget
    const scrollTop = container.scrollTop
    const scrollHeight = container.scrollHeight
    const clientHeight = container.clientHeight
    const scrolledPercent = ((scrollTop + clientHeight) / scrollHeight) * 100

    if (scrolledPercent >= 95) {
      this.submitTarget.disabled = false
    } else {
      this.submitTarget.disabled = true
    }
  }
}
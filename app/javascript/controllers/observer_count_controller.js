import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ["item", "count"]

  connect() {
    this.refreshCount()
  }

  itemTargetConnected(element) {
    this.refreshCount()
  }

  itemTargetDisconnected(element) {
    this.refreshCount()
  }

  refreshCount() {
    const count = this.itemTargets.length
    if (this.countTarget) {
      this.countTarget.innerText = count
    }
  }
}
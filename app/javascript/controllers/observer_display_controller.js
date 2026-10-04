import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ["item", "display"]

  connect() {
    this.refreshDisplay()
  }

  itemTargetConnected(element) {
    this.refreshDisplay()
  }

  itemTargetDisconnected(element) {
    this.refreshDisplay()
  }

  refreshDisplay() {
    if (this.itemTargets.length > 0) {
      this.displayTarget.classList.remove("hidden")
    } else {
      this.displayTarget.classList.add("hidden")
    }
  }
}

// How to use :
// <div data-controller="observer-display">
//   <div data-observer-display-target="display" class="hidden">
//     Hello, items are present !
//   </div>
//   <div data-observer-display-target="item">Item 1</div>
//   <div data-observer-display-target="item">Item 2</div>
// </div>
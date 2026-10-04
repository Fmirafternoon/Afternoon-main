import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  perform(e) {
    e.preventDefault()

    if (this.isInsideModal()) {
      this.emptyModal()
    } else {
      history.back()
    }
  }

  isInsideModal() {
    return this.element.closest('[data-controller~="turbo-modal"]') != null
  }

  emptyModal() {
    const turboModalController = this.element.closest('[data-controller~="turbo-modal"]').turboModal
    turboModalController.hide()
  }
}

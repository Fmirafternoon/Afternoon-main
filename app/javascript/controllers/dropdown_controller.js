import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['menu', 'button']
  static classes = ['hidden']

  connect() {
    document.addEventListener('click', this.outsideClick.bind(this))
  }

  disconnect() {
    document.removeEventListener('click', this.outsideClick.bind(this))
    this.menuTarget.classList.add(this.hiddenClass)
  }

  toggle() {
    this.menuTarget.classList.toggle(this.hiddenClass)
  }

  outsideClick(event) {
    if (!this.element.contains(event.target) && !this.menuTarget.classList.contains(this.hiddenClass)) {
      this.menuTarget.classList.add(this.hiddenClass)
    }
  }
}

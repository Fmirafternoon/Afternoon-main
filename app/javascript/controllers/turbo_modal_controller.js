import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ['backdrop', 'content']

  connect() {
    this.element['turboModal'] = this
    this.observeContent()
    this.registerEscapeKey()
  }

  observeContent() {
    var callback = function (mutationsList) {
      for (var mutation of mutationsList) {
        if (mutation.type == 'childList') {
          if (this.contentTarget.children.length == 0) {
            this.hide()
          } else {
            this.show()
          }
        }
      }
    }.bind(this)
    this.observer = new MutationObserver(callback)
    this.observer.observe(this.contentTarget, { childList: true })
  }

  close(event) {
    event.preventDefault()
    this.hide()
  }

  submit(e) {
    if (e.detail.success) {
      this.hide()
    }
  }

  backdrop(event) {
    if (event.target === this.backdropTarget) {
      this.hide()
    }
  }

  show() {
    this.element.classList.remove('hidden')
  }

  hide() {
    this.element.parentElement.removeAttribute("src")
    this.element.classList.add('hidden')
  }

  registerEscapeKey() {
    this.escapeKeyHandler = this.handleEscapeKey.bind(this)
    document.addEventListener('keydown', this.escapeKeyHandler)
  }

  unregisterEscapeKey() {
    document.removeEventListener('keydown', this.escapeKeyHandler)
  }

  handleEscapeKey(event) {
    if (event.key === 'Escape' || event.keyCode === 27) {
      this.hide()
    }
  }

  disconnect() {
    this.unregisterEscapeKey()
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}
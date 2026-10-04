import { Controller } from "@hotwired/stimulus"

// Usage: data-controller="character-counter" data-character-counter-max-value="500" data-character-counter-min-value="300"
export default class extends Controller {
  static targets = ["input"]
  static values = { max: Number, min: Number }

  connect() {
    this.parent = this.element.parentElement
    if (this.parent) {
      this.parent.classList.add('relative')
    }

    this.counterElement = document.createElement('div')
    this.counterElement.className = 'absolute right-0 bottom-0 text-xs text-gray-400 bg-white bg-opacity-80 px-1 rounded pointer-events-none'
    this.parent.appendChild(this.counterElement)
    this.update()
    this.element.addEventListener('input', this.update.bind(this))
  }

  update() {
    const length = this.element.value.length
    const max = this.maxValue || 500
    const min = this.minValue || 0
    if (this.counterElement) {
      this.counterElement.textContent = `${length}/${max}`
      if (length > max || length < min) {
        this.counterElement.classList.add('text-red-500', length > max)
        this.counterElement.classList.add('text-red-500', length < min)
      } else {
        this.counterElement.classList.remove('text-red-500')
      }
    }
  }
}
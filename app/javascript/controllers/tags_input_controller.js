import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "container", "hiddenInputs"]
  static values = {
    name: String,
    tags: { type: Array, default: [] }
  }

  connect() {
    this.renderTags()
  }

  add(event) {
    event.preventDefault()
    const value = this.inputTarget.value.trim()
    if (value && !this.tagsValue.includes(value)) {
      this.tagsValue = [...this.tagsValue, value]
      this.inputTarget.value = ""
      this.renderTags()
    }
  }

  addOnEnter(event) {
    if (event.key === "Enter") {
      this.add(event)
    }
  }

  remove(event) {
    const tag = event.currentTarget.dataset.tag
    this.tagsValue = this.tagsValue.filter(t => t !== tag)
    this.renderTags()
  }

  renderTags() {
    // Render pills
    this.containerTarget.innerHTML = this.tagsValue.map(tag => `
      <span class="inline-flex items-center bg-gray-100 rounded-full px-3 py-1 text-sm">
        <span class="mr-1">${this.escapeHtml(tag)}</span>
        <button type="button" data-action="click->tags-input#remove" data-tag="${this.escapeHtml(tag)}" class="text-red-500 hover:text-red-700">&times;</button>
      </span>
    `).join("")

    // Render hidden inputs
    this.hiddenInputsTarget.innerHTML = this.tagsValue.map(tag =>
      `<input type="hidden" name="${this.nameValue}" value="${this.escapeHtml(tag)}">`
    ).join("")
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}

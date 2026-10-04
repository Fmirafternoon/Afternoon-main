import { Controller } from "@hotwired/stimulus"

export default class Reveal extends Controller {
  static targets = ["content", "iconOpen", "iconClosed"]
  static values = { storageKey: String }

  connect() {
    // Récupérer l'état depuis localStorage
    const storageKey = this.storageKeyValue || "reveal_state"
    const savedState = localStorage.getItem(storageKey)

    if (savedState !== null) {
      // Si on a un état sauvé, l'utiliser
      const isOpen = JSON.parse(savedState)
      if (isOpen) {
        this.show()
      } else {
        this.hide()
      }
    } else {
      // Pas d'état sauvé, détecter l'état actuel du DOM et le sauver
      const isCurrentlyVisible = !this.contentTargets[0]?.classList.contains("hidden")
      this.saveState(isCurrentlyVisible)
      this.updateIcons(isCurrentlyVisible)
    }
  }

  toggle() {
    const isCurrentlyHidden = this.contentTargets[0]?.classList.contains("hidden")

    if (isCurrentlyHidden) {
      this.show()
    } else {
      this.hide()
    }
  }

  show() {
    this.contentTargets.forEach((item) => {
      item.classList.remove("hidden")
    })
    this.updateIcons(true)
    this.saveState(true)
  }

  hide() {
    this.contentTargets.forEach((item) => {
      item.classList.add("hidden")
    })
    this.updateIcons(false)
    this.saveState(false)
  }

  updateIcons(isOpen) {
    if (isOpen) {
      // Contenu ouvert : montrer flèche vers le haut, cacher flèche vers le bas
      this.iconOpenTargets.forEach(icon => icon.classList.remove("hidden"))
      this.iconClosedTargets.forEach(icon => icon.classList.add("hidden"))
    } else {
      // Contenu fermé : montrer flèche vers le bas, cacher flèche vers le haut
      this.iconOpenTargets.forEach(icon => icon.classList.add("hidden"))
      this.iconClosedTargets.forEach(icon => icon.classList.remove("hidden"))
    }
  }

  saveState(isOpen) {
    const storageKey = this.storageKeyValue || "reveal_state"
    localStorage.setItem(storageKey, JSON.stringify(isOpen))
  }
}
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  values = {}

  connect() {
    document.querySelectorAll('[data-action="conditional-visibility#click"]').forEach(element => {
      this.values[this.toName(element)] = element.value
      this.toggle(element, { connecting: true })
    })
  }

  click(event) {
    this.toggle(event.currentTarget)
  }

  toggle(element, { connecting = false } = {}) {
    const name = this.toName(element)
    const value = element.value
    this.values[name] = value

    document.querySelectorAll(`[data-show-condition]`).forEach(el => {
      const condition = el.dataset.showCondition
      if (this.evaluateCondition(condition)) {
        el.classList.remove('hidden')
        this.enableFormInput(el)
      } else {
        el.classList.add('hidden')
        this.disableFormInput(el)
        if (!connecting) {
          this.resetFormInput(el)
        }
      }
    })
  }

  /**
   * Évalue une condition sous forme de chaîne.
   * On supporte ici :
   * - des conditions simples, par exemple "role=='admin'"
   * - des conditions combinées avec OR ("||") et AND ("&&")
   *
   * Exemples :
   *    "role=='admin' || role=='agent'"
   *    "status=='active' && type=='premium'"
   */
  evaluateCondition(condition) {
    const orParts = condition.split('||').map(part => part.trim())
    // Si l'une des conditions OU est vraie, on retourne true
    for (const orPart of orParts) {
      const andParts = orPart.split('&&').map(part => part.trim())
      let allMatch = true
      for (const cond of andParts) {
        const [field, expectedRaw] = cond.split('==').map(s => s.trim())
        if (!field || !expectedRaw) {
          console.warn(`Condition invalide : ${cond}`)
          allMatch = false
          break
        }
        // Suppression des guillemets autour de la valeur attendue
        let expected = expectedRaw
        if ((expected.startsWith("'") && expected.endsWith("'")) ||
          (expected.startsWith('"') && expected.endsWith('"'))) {
          expected = expected.slice(1, -1)
        }
        if (this.values[field] !== expected) {
          allMatch = false
          break
        }
      }
      if (allMatch) return true
    }
    return false
  }

  resetFormInput(element) {
    element.querySelectorAll('input[type="checkbox"]').forEach(input => { input.checked = false })
    element.querySelectorAll('input[type="radio"]').forEach(input => { input.checked = false })
    element.querySelectorAll('input[type="text"]').forEach(input => { input.value = '' })
    element.querySelectorAll('select').forEach(select => { select.selectedIndex = 0 })
    element.querySelectorAll('select[data-controller="select"]').forEach(select => {
      if (select.tomselect) { select.tomselect.clear() }
    })
  }

  disableFormInput(element) {
    element.querySelectorAll('input').forEach(input => { input.disabled = true })
    element.querySelectorAll('select').forEach(select => { select.disabled = true })
  }

  enableFormInput(element) {
    element.querySelectorAll('input').forEach(input => { input.disabled = false })
    element.querySelectorAll('select').forEach(select => { select.disabled = false })
  }

  // Extrait le nom du champ à partir de l'attribut name (exemple: "user[role]" devient "role")
  toName(element) {
    return element.name.replace(/^.*\[(.*)\]$/, '$1')
  }
}
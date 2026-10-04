import axios from "axios"
import { ApplicationController, useDebounce } from 'stimulus-use'

export default class extends ApplicationController {
  static debounces = ['search']

  static targets = ["input", "results", "siren"]

  connect() {
    useDebounce(this, { wait: 300 })
    this.lastResults = []
    this.clickedOnOption = false
  }

  async search() {
    const query = this.inputTarget.value.trim()
    if (query.length < 3) {
      this.clearResults()
      return
    }
    const url = `https://recherche-entreprises.api.gouv.fr/search?q=${encodeURIComponent(query)}&per_page=5`
    try {
      const response = await axios.get(url)
      this.lastResults = response.data.results
      this.showResults(response.data.results, query)
    } catch (error) {
      console.error("Error fetching companies", error)
      this.clearResults()
    }
  }

  onBlur() {
    setTimeout(() => {
      if (!this.clickedOnOption) {
        this.hideResults()
      }
      this.clickedOnOption = false
    }, 200)
  }

  selectMatch(match) {
    this.inputTarget.value = match.nom_complet
    this.hideResults()
  }

  hideResults() {
    this.resultsTarget.innerHTML = ""
  }

  showResults(results, query) {
    const ul = document.createElement("ul")
    ul.className = "z-30 absolute top-full left-0 bg-white border border-gray-300 rounded shadow-lg"

    results.forEach(result => {
      const label = result.nom_complet
      const dataCompany = encodeURIComponent(JSON.stringify(result))

      const li = document.createElement("li")
      li.setAttribute("data-action", "click->autocomplete-company#select")
      li.setAttribute("data-company", dataCompany)
      li.className = "text-sm cursor-pointer px-4 py-2 hover:bg-gray-200"
      li.innerHTML = `
        ${label} (${result.siren}) <br>
        <span class="text-xs text-gray-500">
          ${result.siege.code_postal}
          ${result.siege.libelle_commune}
        </span>
      `

      ul.appendChild(li)
    })

    if (results.length <= 0) {
      const li = document.createElement("li")
      li.textContent = "Aucune entreprise trouvée"
      li.className = "text-sm cursor-pointer px-4 py-2 italic text-mute-700"
      ul.appendChild(li)
    }
    this.hideResults()
    this.sirenTarget.value = ""

    this.resultsTarget.appendChild(ul)
  }

  reOpen() {
    if (this.lastResults.length > 0) {
      this.showResults(this.lastResults, this.inputTarget.value)
    }
  }

  clearResults() {
    this.hideResults()
    this.lastResults = []
  }

  select(event) {
    this.clickedOnOption = true

    const data = decodeURIComponent(event.currentTarget.getAttribute("data-company"))
    const result = JSON.parse(data)

    this.inputTarget.value = result.nom_complet

    if (this.hasSirenTarget) {
      this.sirenTarget.value = result.siren
    }

    this.clearResults()
    event.stopPropagation()
  }
}
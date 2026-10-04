import axios from "axios"
import { ApplicationController, useDebounce } from 'stimulus-use'

export default class extends ApplicationController {
  static debounces = ['search']
  static targets = ["input", "results", "address", "zip", "city", "lat", "lng"]

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

    const url = (this.hasAddressTarget) ?
      `https://api-adresse.data.gouv.fr/search/?q=${encodeURIComponent(query)}` :
      `https://api-adresse.data.gouv.fr/search/?q=${encodeURIComponent(query)}&type=municipality`


    try {
      const response = await axios.get(url)
      this.lastResults = response.data.features
      this.showResults(response.data.features, query)
    } catch (error) {
      console.error("Error fetching addresses", error)
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
    if (this.hasAddressTarget) {
      this.inputTarget.value = match.name + " " + match.postcode + " " + match.city
    } else {
      this.inputTarget.value = match.postcode + " " + match.city
    }
    this.hideResults()
  }

  hideResults() {
    this.resultsTarget.innerHTML = ""
  }

  showResults(features, query) {
    const ul = document.createElement("ul")
    ul.className = "z-30 absolute top-full left-0 bg-white border border-gray-300 rounded shadow-lg"

    features.forEach(feature => {
      const label = (this.hasAddressTarget) ?
        feature.properties.name + " " + feature.properties.postcode + " " + feature.properties.city :
        feature.properties.postcode + " " + feature.properties.city

      const dataAddress = encodeURIComponent(JSON.stringify(feature))

      const li = document.createElement("li")
      li.setAttribute("data-action", "click->autocomplete-address#select")
      li.setAttribute("data-address", dataAddress)
      li.className = "text-sm cursor-pointer px-4 py-2 hover:bg-gray-200"
      li.textContent = label

      ul.appendChild(li)
    })

    if (features.length <= 0) {
      const li = document.createElement("li")
      li.textContent = "Aucune adresse trouvée"
      li.className = "text-sm cursor-pointer px-4 py-2 italic text-mute-700"
      ul.appendChild(li)
    }
    this.hideResults()

    if (this.hasAddressTarget) {
      this.addressTarget.value = ""
    }
    this.zipTarget.value = ""
    this.cityTarget.value = ""
    this.latTarget.value = ""
    this.lngTarget.value = ""

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

    const data = decodeURIComponent(event.currentTarget.getAttribute("data-address"))
    const feature = JSON.parse(data)
    const props = feature.properties

    if (this.hasAddressTarget) {
      this.inputTarget.value = props.name + " " + props.postcode + " " + props.city
    } else {
      this.inputTarget.value = props.postcode + " " + props.city
    }

    if (this.hasAddressTarget) {
      this.addressTarget.value = props.name
    }
    if (this.hasZipTarget) {
      this.zipTarget.value = props.postcode
    }
    if (this.hasCityTarget) {
      this.cityTarget.value = props.city
    }
    if (this.hasLatTarget) {
      this.latTarget.value = feature.geometry.coordinates[1]
    }
    if (this.hasLngTarget) {
      this.lngTarget.value = feature.geometry.coordinates[0]
    }
    this.clearResults()
    event.stopPropagation()

  }
}
import { Controller } from "@hotwired/stimulus"
import IMask from 'imask';

export default class extends Controller {
  static values = {
    type: String,     // Type prédéfini: date, number, currency, etc.
    options: Object,  // Options supplémentaires pour personnaliser IMask
    mask: String      // Masque personnalisé
  }

  connect() {
    this.createMask()
  }

  disconnect() {
    if (this.maskInstance) {
      this.maskInstance.destroy()
    }
  }

  /**
   * Crée une instance d'IMask avec les options appropriées.
   */
  createMask() {
    let maskOptions = {}

    // Si un type prédéfini est fourni
    if (this.hasTypeValue) {
      switch (this.typeValue) {
        case "year":
          maskOptions = {
            mask: 'YYYY',
            lazy: true,
            blocks: {
              YYYY: {
                mask: IMask.MaskedRange,
                from: 1900,
                to: 2099,
                placeholderChar: 'A'
              }
            },
            overwrite: true
          }
          break

        case "date":
        case "month-year":
          maskOptions = {
            mask: 'MM/YYYY',
            lazy: true,
            blocks: {
              MM: {
                mask: IMask.MaskedRange,
                from: 1,
                to: 12,
                placeholderChar: 'M'
              },
              YYYY: {
                mask: IMask.MaskedRange,
                from: 1900,
                to: 2099,
                placeholderChar: 'A'
              }
            },
            overwrite: true
          }
          break

        case "number":
          maskOptions = {
            mask: Number,
            thousandsSeparator: ' ',
            radix: ',',
            mapToRadix: ['.']
          }
          break

        case "currency":
          maskOptions = {
            mask: Number,
            scale: 2,
            signed: false,
            thousandsSeparator: ' ',
            padFractionalZeros: true,
            normalizeZeros: true,
            radix: ',',
            mapToRadix: ['.']
          }
          break

        case "phone":
          maskOptions = {
            mask: '+{33} 0 00 00 00 00',
            lazy: false
          }
          break
      }
    }
    // Sinon, si un masque personnalisé est fourni
    else if (this.hasMaskValue) {
      maskOptions = {
        mask: this.maskValue
      }
    }

    // Fusionner avec les options personnalisées (si fournies)
    if (this.hasOptionsValue) {
      maskOptions = { ...maskOptions, ...this.optionsValue }
    }

    // Créer l'instance de masque si des options sont définies
    if (Object.keys(maskOptions).length > 0) {
      this.maskInstance = IMask(this.element, maskOptions)

      // Propager les événements de changement pour fonctionner avec les validations Rails
      this.maskInstance.on('accept', () => {
        this.element.dispatchEvent(new Event('input', { bubbles: true }))
        this.element.dispatchEvent(new Event('change', { bubbles: true }))
      })
    }
  }
}
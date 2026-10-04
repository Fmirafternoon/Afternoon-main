import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['button', 'content', 'wrapper', 'dot']
  static classes = ['active', 'inactive']
  static values = { current: { type: Number, default: 0 } }

  // Flag pour indiquer un défilement programmé (vs. un défilement utilisateur)
  isUserInitiatedScroll = true

  connect() {
    // Ajouter console.log pour debug
    console.log("StepsCarousel controller connected")

    // Toujours initialiser les classes sur les boutons au démarrage
    this.updateButtonsState(this.currentValue)

    // Mettre à jour l'interface complète
    this.updateUI(this.currentValue)

    // Set up scroll listener
    if (this.hasWrapperTarget) {
      this.wrapperTarget.addEventListener('scroll', this.handleScroll.bind(this))
    }

    // Add resize listener
    window.addEventListener('resize', this.handleResize.bind(this))
  }

  disconnect() {
    // Clean up event listeners
    window.removeEventListener('resize', this.handleResize.bind(this))
    if (this.hasWrapperTarget) {
      this.wrapperTarget.removeEventListener('scroll', this.handleScroll.bind(this))
    }
  }

  handleResize() {
    // Re-center current slide after resize
    this.scrollToSlide(this.currentValue)
  }

  handleScroll() {
    if (!this.hasWrapperTarget) return

    // Ne pas mettre à jour la valeur courante si le défilement a été programmé
    if (!this.isUserInitiatedScroll) return

    // Si l'utilisateur fait défiler, déterminer quelle slide est centrée
    this.updateCurrentFromScroll()
  }

  updateCurrentFromScroll() {
    if (!this.hasWrapperTarget || !this.hasContentTarget) return

    const wrapper = this.wrapperTarget
    const slideWidth = wrapper.offsetWidth * 0.9 // 90% de la largeur du wrapper
    const slidesArray = Array.from(this.contentTargets)
    const scrollPosition = wrapper.scrollLeft

    // Find closest slide based on position
    let closestSlideIndex = 0
    let minDistance = Infinity

    slidesArray.forEach((slide, i) => {
      const slideOffset = slide.offsetLeft
      const slideCenter = slideOffset + (slide.offsetWidth / 2)
      const viewportCenter = scrollPosition + (wrapper.offsetWidth / 2)
      const distance = Math.abs(viewportCenter - slideCenter)

      if (distance < minDistance) {
        minDistance = distance
        closestSlideIndex = i
      }
    })

    // Only update if different from current
    if (closestSlideIndex !== this.currentValue) {
      // Mettre à jour la valeur courante via la propriété value pour déclencher currentValueChanged
      this.currentValue = closestSlideIndex
    }
  }

  activate(event) {
    console.log("Activate called", event.currentTarget)

    // Get index from data attribute
    const element = event.currentTarget
    const index = parseInt(element.dataset.index || 0)

    console.log("Activate index:", index)

    // Ensure we have a valid index
    if (isNaN(index) || index < 0 || index >= this.contentTargets.length) {
      console.warn("Invalid index:", index)
      return
    }

    // Don't do anything if clicking already active element
    if (index === this.currentValue) return

    // Set new index and update UI
    this.currentValue = index
  }

  activateDot(event) {
    // Get index from the dot element
    const dot = event.currentTarget
    const index = parseInt(dot.dataset.index)

    // Set new index and update UI
    this.currentValue = index
  }

  // Handle "previous" button click
  prev() {
    if (this.currentValue > 0) {
      this.currentValue = this.currentValue - 1
    }
  }

  // Handle "next" button click
  next() {
    if (this.currentValue < this.contentTargets.length - 1) {
      this.currentValue = this.currentValue + 1
    }
  }

  // Handle changes to the current value
  currentValueChanged() {
    console.log("Current value changed to:", this.currentValue)
    this.updateUI(this.currentValue)
  }

  updateUI(index) {
    // Ensure index is valid
    if (index < 0 || index >= this.contentTargets.length) {
      console.warn('Tentative d\'accéder à un index en dehors des limites:', index)
      return
    }

    // Update buttons state
    this.updateButtonsState(index)

    // Update dots state (if they exist)
    if (this.hasDotTarget) {
      this.updateDotsState(index)
    }

    // Scroll to the selected slide
    this.scrollToSlide(index)
  }

  updateButtonsState(index) {
    if (!this.hasButtonTarget) return

    console.log("Updating button states for index:", index)

    this.buttonTargets.forEach((button, i) => {
      const activeClass = button.dataset.activeClass

      if (i === index) {
        button.classList.remove(this.inactiveClass)
        button.classList.add(activeClass)
        console.log(`Button ${i} activated`)
      } else {
        button.classList.remove(activeClass)
        button.classList.add(this.inactiveClass)
        console.log(`Button ${i} deactivated`)
      }
    })
  }

  updateDotsState(index) {
    this.dotTargets.forEach((dot, i) => {
      if (i === index) {
        dot.classList.remove(this.inactiveClass, 'bg-mute-300')
        dot.classList.add(this.activeClass, 'bg-primary-500')
      } else {
        dot.classList.remove(this.activeClass, 'bg-primary-500')
        dot.classList.add(this.inactiveClass, 'bg-mute-300')
      }
    })
  }

  scrollToSlide(index) {
    if (!this.hasWrapperTarget || !this.hasContentTarget) return

    const wrapper = this.wrapperTarget
    const targetSlide = this.contentTargets[index]

    if (!targetSlide) {
      console.warn(`No slide found at index ${index}`)
      return
    }

    // Désactiver temporairement la mise à jour de l'index par l'événement de défilement
    this.isUserInitiatedScroll = false

    // Get the offset of the target slide relative to the wrapper
    const slideOffset = targetSlide.offsetLeft - wrapper.offsetLeft

    // Scroll wrapper to center the slide
    const targetPosition = slideOffset - ((wrapper.offsetWidth - targetSlide.offsetWidth) / 2)

    console.log("Scrolling to position:", targetPosition)

    wrapper.scrollTo({
      left: targetPosition,
      behavior: 'smooth'
    })

    // Réactiver l'événement de défilement après l'animation (environ 300ms)
    setTimeout(() => {
      this.isUserInitiatedScroll = true
    }, 500)
  }
}
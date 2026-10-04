import { Controller } from "@hotwired/stimulus"

// Gère la partie interactive du wizard
export default class extends Controller {
  static targets = ["step", "progressBar", "nextButton", "backButton"]

  connect() {
    // Initialiser l'animation de la barre de progression
    if (this.hasProgressBarTarget) {
      setTimeout(() => {
        this.progressBarTarget.style.transition = "width 0.5s ease-in-out"
      }, 100)
    }
  }

  // Méthode pour valider le formulaire courant avant de passer à la prochaine étape
  validateCurrentStep(event) {
    // On peut ajouter une validation côté client ici si nécessaire
    // Par exemple, vérifier que les champs obligatoires sont remplis

    // Ajouter une animation de chargement sur le bouton
    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.disabled = true
      this.nextButtonTarget.classList.add("opacity-75")
      // Ajouter une icône de chargement ou un texte "Chargement..." si nécessaire
    }
  }

  // Méthode pour gérer l'action de retour en arrière
  goBack(event) {
    if (this.hasBackButtonTarget) {
      this.backButtonTarget.disabled = true
      this.backButtonTarget.classList.add("opacity-75")
    }
  }
}
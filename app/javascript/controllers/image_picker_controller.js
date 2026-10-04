import { Controller } from '@hotwired/stimulus'
import axios from 'axios'

// Handles image preview / removal logic for the AvatarInput component.
// Expected targets in the DOM (see `app/inputs/avatar_input.rb`):
// - input     : <input type="file" ... data-action="image-picker#preview">
// - preview   : <div class="preview" ...>
// - hint      : container shown when no image is selected ("Déposer l'image …")
// - remove    : × button to clear the chosen image
// - keep      : hidden field that indicates whether the current image should be kept (1) or replaced/removed (0)
// - urlField  : hidden field that will receive the Cloudinary URL

export default class extends Controller {
  static targets = [
    'input',
    'preview',
    'hint',
    'remove',
    'keep',
    'urlField'
  ]

  connect () {
    // Ensure the correct visibility state on page load.
    this.toggleElements()
  }

  /*
   * Triggered when the user selects a file.
   */
  preview () {
    const file = this.inputTarget.files[0]

    if (!file) {
      // Nothing selected – keep current state.
      return
    }

    // Show immediate preview with FileReader
    const reader = new FileReader()
    reader.onload = e => {
      this.previewTarget.style.backgroundImage = `url('${e.target.result}')`
      this.previewTarget.classList.remove('hidden')
    }
    reader.readAsDataURL(file)

    // Hide upload hint and show remove button.
    this.hintTarget.classList.add('hidden')
    this.removeTarget.classList.remove('hidden')

    // Mark avatar as changed so back-end can replace it.
    if (this.hasKeepTarget) this.keepTarget.value = 0

    // Upload to Cloudinary
    this.uploadToCloudinary(file)
  }

  /*
   * Upload file to Cloudinary and update the URL field
   */
  async uploadToCloudinary(file) {
    const formData = new FormData()
    formData.append('file', file)
    formData.append('upload_preset', 'resume') // Utilise le même preset que les autres uploads

    try {
      const response = await axios.post('https://api.cloudinary.com/v1_1/hxv1bv0di/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      })

      // Update the hidden URL field with Cloudinary URL
      if (this.hasUrlFieldTarget) {
        this.urlFieldTarget.value = response.data.secure_url
      }

      // Update preview with Cloudinary URL (higher quality)
      this.previewTarget.style.backgroundImage = `url('${response.data.secure_url}')`

    } catch (error) {
      console.error('Erreur lors de l\'upload sur Cloudinary:', error)
      console.error('Response data:', error.response?.data)
      // Optionally show error to user
    }
  }

  /*
   * Triggered when the × button is clicked.
   */
  remove () {
    // Clear file input & preview background.
    this.inputTarget.value = ''
    this.previewTarget.style.backgroundImage = ''

    // Clear the URL field
    if (this.hasUrlFieldTarget) {
      this.urlFieldTarget.value = ''
    }

    // Reset visibility.
    this.previewTarget.classList.add('hidden')
    this.hintTarget.classList.remove('hidden')
    this.removeTarget.classList.add('hidden')

    // Mark the avatar as removed.
    if (this.hasKeepTarget) this.keepTarget.value = 0
  }

  /*
   * Ensures elements reflect the initial state rendered by the server.
   */
  toggleElements () {
    const hasImage = !this.previewTarget.classList.contains('hidden')

    this.hintTarget.classList.toggle('hidden', hasImage)
    this.removeTarget.classList.toggle('hidden', !hasImage)
  }
}
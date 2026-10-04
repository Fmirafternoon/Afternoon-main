import { Controller } from "@hotwired/stimulus"
import { patch } from '@rails/request.js'
import axios from "axios"

export default class ResumeUploadController extends Controller {
  static targets = ["dropzone", "uploads"]

  static values = {
    candidateId: String
  }

  connect() {
    this.dropzoneTarget.addEventListener("dragover", this.handleDragOver.bind(this))
    this.dropzoneTarget.addEventListener("dragleave", this.handleDragLeave.bind(this))
    this.dropzoneTarget.addEventListener("drop", this.handleDrop.bind(this))
    this.dropzoneTarget.addEventListener("click", this.handleClick.bind(this))
    this.createFileInput()
  }

  createFileInput() {
    this.fileInput = document.createElement("input")
    this.fileInput.type = "file"
    this.fileInput.multiple = false
    this.fileInput.style.display = "none"
    this.fileInput.addEventListener("change", this.handleFileSelect.bind(this))
    this.element.appendChild(this.fileInput)
  }

  handleClick(event) {
    this.fileInput.click()
  }

  handleFileSelect(event) {
    const files = event.target.files
    if (files.length > 0) {
      this.startUpload(files[0])
    }
    this.fileInput.value = ""
  }

  handleDragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropzoneTarget.classList.add("bg-mute-200")
  }

  handleDragLeave(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropzoneTarget.classList.remove("bg-mute-200")
  }

  handleDrop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.dropzoneTarget.classList.remove("bg-mute-200")

    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.startUpload(files[0])
    }
  }

  startUpload(file) {
    // Récupération et clonage du template
    const template = document.querySelector("[data-upload-item-template]")
    const uploadItem = template.content.cloneNode(true).firstElementChild

    // Mise à jour des éléments dynamiques
    uploadItem.querySelector("[data-file-name]").textContent = file.name;

    // Cacher la dropzone
    this.dropzoneTarget.remove()

    // Ajout de l'upload item dans la zone d'uploads
    this.uploadsTarget.appendChild(uploadItem);

    // Création du FormData pour l'upload sur Cloudinary
    const formData = new FormData();
    formData.append("file", file);
    formData.append("upload_preset", "resume"); // Remplacez par votre upload preset

    // Upload avec Axios et gestion de la progression
    axios.post("https://api.cloudinary.com/v1_1/hxv1bv0di/upload", formData, {
      headers: { "Content-Type": "multipart/form-data" },
      onUploadProgress: progressEvent => {
        const percentCompleted = Math.round((progressEvent.loaded * 100) / progressEvent.total);
        const progressBar = uploadItem.querySelector("[data-progress-bar]");
        const radius = Number(progressBar.getAttribute('r'));
        const circumference = 2 * Math.PI * radius;
        progressBar.style.strokeDasharray = circumference;
        progressBar.style.strokeDashoffset = circumference * (1 - percentCompleted / 100);
      }
    })
      .then(response => {
        this.updateCandidate(response.data, uploadItem, file);
      })
      .catch(error => {
        console.error("Erreur lors de l'upload sur Cloudinary :", error);
        uploadItem.querySelector(".progress-text").textContent = "Erreur lors de l'upload";
      });
  }

  async updateCandidate(uploadInfo, uploadItem, file) {
    const response =
      await patch(`/agent/candidates/${this.candidateIdValue}`,
        {
          body: JSON.stringify({
            candidate: {
              resume_file_name: uploadInfo.original_filename || file.name,
              resume_url: uploadInfo.secure_url
            }
          }),
          responseKind: 'turbo-stream'
        }
      )
    const html = await response.text
    Turbo.renderStreamMessage(html)
  }
}
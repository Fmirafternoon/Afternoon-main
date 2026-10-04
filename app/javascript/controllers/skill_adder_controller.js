import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input","required","seniority"]
  static values = {
    url: String,
    skills: Array,
  }

  add() {
    const newSkill = this.inputTarget.value.trim()
    const required = this.requiredTarget.checked
    const seniority = this.hasSeniorityTarget ? this.seniorityTarget.value : ""
    const skill = { name: newSkill, required: required, seniority: seniority }
    if (newSkill && !this.skillsValue.some(s => s.name === newSkill)) {
      const skills = [...this.skillsValue, skill]
      const params = new URLSearchParams()
      skills.forEach(skill => {
        params.append("skills[][name]", skill.name)
        params.append("skills[][required]", skill.required ? "1" : "0")
        params.append("skills[][seniority]", skill.seniority || "")
      })
      window.location.href = `${this.urlValue}?${params.toString()}`
    }
  }
}

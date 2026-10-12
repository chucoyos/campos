import { Controller } from "@hotwired/stimulus"

// Muestra el selector de Cliente o Transportista según el rol elegido.
export default class extends Controller {
  static targets = ["role", "field"]

  connect() {
    this.toggle()
  }

  toggle() {
    const role = this.roleTarget.value
    this.fieldTargets.forEach((field) => {
      const visible = field.dataset.role === role
      field.classList.toggle("hidden", !visible)
      field.querySelector("select").disabled = !visible
    })
  }
}

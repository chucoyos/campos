import { Controller } from "@hotwired/stimulus"

// Muestra los selectores de Cliente y Transportista solo para roles externos (data-roles separados por espacio).
export default class extends Controller {
  static targets = ["role", "field"]

  connect() {
    this.toggle()
  }

  toggle() {
    const role = this.roleTarget.value
    this.fieldTargets.forEach((field) => {
      const visible = field.dataset.roles.split(" ").includes(role)
      field.classList.toggle("hidden", !visible)
      field.querySelector("select").disabled = !visible
    })
  }
}

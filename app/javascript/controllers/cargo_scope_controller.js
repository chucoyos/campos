import { Controller } from "@hotwired/stimulus"

// Alterna entre carga general y contenedor, y filtra los contenedores por cliente.
export default class extends Controller {
  static targets = [ "scope", "containerField", "container", "client" ]

  connect() {
    this.toggle()
  }

  toggle() {
    const withContainer = this.scopeTargets.find((radio) => radio.checked)?.value === "container"
    this.containerFieldTarget.hidden = !withContainer
    this.containerTarget.required = withContainer
    if (!withContainer) this.containerTarget.value = ""
    this.filter()
  }

  filter() {
    if (!this.hasClientTarget) return
    const clientId = this.clientTarget.value
    Array.from(this.containerTarget.options).forEach((option) => {
      const hidden = option.value !== "" && clientId !== "" && option.dataset.clientId !== clientId
      option.hidden = hidden
      option.disabled = hidden
    })
    if (this.containerTarget.selectedOptions[0]?.disabled) this.containerTarget.value = ""
  }
}

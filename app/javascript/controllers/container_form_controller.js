import { Controller } from "@hotwired/stimulus"

// Oculta el estado cuando hay MBL: el contenedor siempre inicia como "activo".
export default class extends Controller {
  static targets = [ "masterBl", "statusField", "status" ]

  connect() {
    this.toggle()
  }

  toggle() {
    const withMasterBl = this.masterBlTarget.value !== ""
    this.statusFieldTarget.hidden = withMasterBl
    this.statusTarget.disabled = withMasterBl
  }
}

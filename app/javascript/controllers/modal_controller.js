import { Controller } from "@hotwired/stimulus"

// Modal basado en <dialog>: se cierra con Esc, con el botón o al tocar fuera del contenido.
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}

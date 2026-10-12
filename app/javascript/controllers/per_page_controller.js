import { Controller } from "@hotwired/stimulus"

// Al cambiar los registros por página se recarga el listado desde la página 1.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}

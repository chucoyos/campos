import { Controller } from "@hotwired/stimulus"

// Alterna una línea entre su resumen y su formulario de edición.
export default class extends Controller {
  static targets = [ "summary", "form" ]

  open() {
    this.summaryTarget.hidden = true
    this.formTarget.hidden = false
    this.formTarget.querySelector("input:not([type=hidden]), select")?.focus()
  }

  close() {
    this.formTarget.hidden = true
    this.summaryTarget.hidden = false
    this.formTarget.querySelector("form")?.reset()
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button", "openIcon", "closeIcon"]

  toggle() {
    const open = this.menuTarget.classList.toggle("hidden") === false
    this.buttonTarget.setAttribute("aria-expanded", open)
    this.openIconTarget.classList.toggle("hidden", open)
    this.closeIconTarget.classList.toggle("hidden", !open)
  }
}

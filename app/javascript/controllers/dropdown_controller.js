import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button"]

  disconnect() {
    this.removeListeners()
  }

  toggle() {
    this.menuTarget.classList.contains("hidden") ? this.open() : this.close()
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.outsideClick = (event) => { if (!this.element.contains(event.target)) this.close() }
    this.escape = (event) => { if (event.key === "Escape") { this.close(); this.buttonTarget.focus() } }
    document.addEventListener("click", this.outsideClick)
    document.addEventListener("keydown", this.escape)
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.removeListeners()
  }

  removeListeners() {
    document.removeEventListener("click", this.outsideClick)
    document.removeEventListener("keydown", this.escape)
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 5000 } }

  connect() {
    // Next frame so the initial off-screen state is painted before sliding in
    requestAnimationFrame(() => {
      this.element.classList.remove("translate-x-full", "opacity-0")
    })
    this.timeout = setTimeout(() => this.close(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  close() {
    clearTimeout(this.timeout)
    this.element.classList.add("translate-x-full", "opacity-0")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
    // Fallback if transitionend never fires (e.g. reduced motion)
    setTimeout(() => this.element.remove(), 600)
  }
}

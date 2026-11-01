import { Controller } from "@hotwired/stimulus"

// Menú de acciones por fila (tres puntos). Usa posición fija para no quedar recortado por contenedores con overflow.
export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.close = this.close.bind(this)
  }

  disconnect() {
    this.removeListeners()
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.contains("hidden") ? this.open() : this.close()
  }

  open() {
    document.dispatchEvent(new CustomEvent("row-actions:open", { detail: this.element }))
    this.menuTarget.classList.remove("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.position()
    this.outsideClick = (event) => { if (!this.element.contains(event.target)) this.close() }
    this.escape = (event) => { if (event.key === "Escape") { this.close(); this.buttonTarget.focus() } }
    this.otherOpened = (event) => { if (event.detail !== this.element) this.close() }
    document.addEventListener("click", this.outsideClick)
    document.addEventListener("keydown", this.escape)
    document.addEventListener("row-actions:open", this.otherOpened)
    window.addEventListener("scroll", this.close, true)
    window.addEventListener("resize", this.close)
    this.menuTarget.querySelector("a, button")?.focus()
  }

  close() {
    this.menuTarget.classList.add("hidden")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.removeListeners()
  }

  position() {
    const rect = this.buttonTarget.getBoundingClientRect()
    const menu = this.menuTarget
    const spaceBelow = window.innerHeight - rect.bottom
    menu.style.left = `${Math.max(8, rect.right - menu.offsetWidth)}px`
    menu.style.top = spaceBelow < menu.offsetHeight + 8
      ? `${Math.max(8, rect.top - menu.offsetHeight - 4)}px`
      : `${rect.bottom + 4}px`
  }

  removeListeners() {
    document.removeEventListener("click", this.outsideClick)
    document.removeEventListener("keydown", this.escape)
    document.removeEventListener("row-actions:open", this.otherOpened)
    window.removeEventListener("scroll", this.close, true)
    window.removeEventListener("resize", this.close)
  }
}

import { Controller } from "@hotwired/stimulus"

// Rota mensajes de espera con un fundido suave para que el tiempo se sienta más corto.
export default class extends Controller {
  static targets = ["message"]
  static values = { messages: Array }

  connect() {
    this.index = 0
    this.timer = setInterval(() => this.next(), 2500)
  }

  disconnect() {
    clearInterval(this.timer)
    clearTimeout(this.fade)
  }

  next() {
    if (!this.hasMessageTarget || this.messagesValue.length < 2) return
    this.index = (this.index + 1) % this.messagesValue.length
    this.messageTarget.classList.add("opacity-0")
    this.fade = setTimeout(() => {
      this.messageTarget.textContent = this.messagesValue[this.index]
      this.messageTarget.classList.remove("opacity-0")
    }, 300)
  }
}

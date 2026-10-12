import { Controller } from "@hotwired/stimulus"

// Sube el archivo directo a S3 (Active Storage direct upload) mostrando el progreso.
export default class extends Controller {
  static targets = [ "input", "submit", "progress", "bar", "error" ]
  static values = { maxSize: Number, tooLarge: String, failed: String }

  connect() {
    this.element.addEventListener("direct-upload:start", () => this.start())
    this.element.addEventListener("direct-upload:progress", (event) => this.progress(event))
    this.element.addEventListener("direct-upload:error", (event) => this.fail(event))
    this.element.addEventListener("direct-upload:end", () => this.progressTarget.classList.add("hidden"))
  }

  validate() {
    const file = this.inputTarget.files[0]
    this.errorTarget.classList.add("hidden")
    if (file && this.maxSizeValue && file.size > this.maxSizeValue) {
      this.inputTarget.value = ""
      this.showError(this.tooLargeValue)
    }
  }

  start() {
    this.submitTarget.disabled = true
    this.barTarget.style.width = "0%"
    this.progressTarget.classList.remove("hidden")
  }

  progress(event) {
    this.barTarget.style.width = `${Math.round(event.detail.progress)}%`
  }

  fail(event) {
    event.preventDefault()
    this.submitTarget.disabled = false
    this.progressTarget.classList.add("hidden")
    this.showError(this.failedValue)
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }
}

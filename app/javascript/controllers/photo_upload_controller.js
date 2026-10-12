import { Controller } from "@hotwired/stimulus"

const MAX_DIMENSION = 1600
const JPEG_QUALITY = 0.82
const SKIP_BELOW_BYTES = 300 * 1024

// Reduce las fotos en el navegador antes de subirlas directo a S3 (Active Storage direct upload).
export default class extends Controller {
  static targets = [ "input", "submit", "progress", "bar", "error" ]
  static values = { max: Number, tooMany: String, failed: String }

  connect() {
    this.progresses = {}
    this.element.addEventListener("direct-upload:initialize", (event) => this.track(event))
    this.element.addEventListener("direct-upload:start", () => this.start())
    this.element.addEventListener("direct-upload:progress", (event) => this.progress(event))
    this.element.addEventListener("direct-upload:error", (event) => this.fail(event))
  }

  async prepare() {
    this.errorTarget.classList.add("hidden")
    let files = Array.from(this.inputTarget.files)
    if (files.length === 0) return

    if (files.length > this.maxValue) {
      this.inputTarget.value = ""
      return this.showError(this.tooManyValue)
    }

    this.submitTarget.disabled = true
    const resized = await Promise.all(files.map((file) => this.resize(file)))
    const transfer = new DataTransfer()
    resized.forEach((file) => transfer.items.add(file))
    this.inputTarget.files = transfer.files
    this.submitTarget.disabled = false
  }

  async resize(file) {
    if (!file.type.startsWith("image/") || file.size < SKIP_BELOW_BYTES) return file

    try {
      const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" })
      const scale = Math.min(1, MAX_DIMENSION / Math.max(bitmap.width, bitmap.height))
      const canvas = document.createElement("canvas")
      canvas.width = Math.round(bitmap.width * scale)
      canvas.height = Math.round(bitmap.height * scale)
      canvas.getContext("2d").drawImage(bitmap, 0, 0, canvas.width, canvas.height)
      bitmap.close()

      const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", JPEG_QUALITY))
      if (!blob || blob.size >= file.size) return file

      const name = file.name.replace(/\.[^.]+$/, "") + ".jpg"
      return new File([ blob ], name, { type: "image/jpeg", lastModified: file.lastModified })
    } catch {
      return file
    }
  }

  track(event) {
    this.progresses[event.detail.id] = 0
  }

  start() {
    this.submitTarget.disabled = true
    this.barTarget.style.width = "0%"
    this.progressTarget.classList.remove("hidden")
  }

  progress(event) {
    this.progresses[event.detail.id] = event.detail.progress
    const values = Object.values(this.progresses)
    const average = values.reduce((sum, value) => sum + value, 0) / values.length
    this.barTarget.style.width = `${Math.round(average)}%`
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

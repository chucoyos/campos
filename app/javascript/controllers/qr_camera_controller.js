import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "video", "form", "token", "status", "start", "stop", "preview" ]
  static values = { unsupported: String, denied: String, reading: String }

  connect() {
    this.scanning = false
  }

  disconnect() {
    this.stop()
  }

  async start() {
    if (!("BarcodeDetector" in window)) {
      this.showStatus(this.unsupportedValue)
      return
    }

    try {
      if (!navigator.mediaDevices?.getUserMedia) {
        this.showStatus(this.unsupportedValue)
        return
      }
      this.detector ||= new BarcodeDetector({ formats: [ "qr_code" ] })
      this.stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: "environment" } }, audio: false })
      this.videoTarget.srcObject = this.stream
      await this.videoTarget.play()
      this.scanning = true
      this.previewTarget.classList.remove("hidden")
      this.startTarget.disabled = true
      this.stopTarget.classList.remove("hidden")
      this.showStatus(this.readingValue)
      this.scanFrame()
    } catch (error) {
      this.stop()
      this.showStatus(error.name === "NotAllowedError" ? this.deniedValue : this.unsupportedValue)
    }
  }

  stop() {
    this.scanning = false
    this.stream?.getTracks().forEach((track) => track.stop())
    this.stream = null
    if (this.hasVideoTarget) this.videoTarget.srcObject = null
    if (this.hasPreviewTarget) this.previewTarget.classList.add("hidden")
    if (this.hasStartTarget) this.startTarget.disabled = false
    if (this.hasStopTarget) this.stopTarget.classList.add("hidden")
  }

  async scanFrame() {
    if (!this.scanning) return

    try {
      const codes = await this.detector.detect(this.videoTarget)
      const token = codes.find((code) => code.rawValue?.trim())?.rawValue?.trim()
      if (token) {
        this.tokenTarget.value = token
        this.stop()
        this.formTarget.requestSubmit()
        return
      }
    } catch {
      this.stop()
      this.showStatus(this.unsupportedValue)
      return
    }

    this.frame = window.requestAnimationFrame(() => this.scanFrame())
  }

  showStatus(message) {
    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("hidden")
  }
}

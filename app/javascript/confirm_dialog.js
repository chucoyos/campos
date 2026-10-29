import { Turbo } from "@hotwired/turbo-rails"

// Reemplaza window.confirm por un diálogo Material 3. El tono sale de data-turbo-confirm-tone
// (danger, success o neutral); sin él se deduce del método DELETE o de acciones de cancelar.
const DANGER_PATH = /\/(cancel|destroy|remove)\b/

function toneFor(form, submitter) {
  const explicit = submitter?.dataset.turboConfirmTone || form?.dataset.turboConfirmTone
  if (explicit) return explicit

  const method = (form?.querySelector("input[name=_method]")?.value || form?.method || "").toLowerCase()
  if (method === "delete" || DANGER_PATH.test(form?.action || "")) return "danger"
  return "neutral"
}

function confirmDialog(message, form, submitter) {
  const dialog = document.getElementById("confirm-dialog")
  if (!dialog) return Promise.resolve(window.confirm(message))

  const tones = JSON.parse(dialog.dataset.tones)
  const tone = tones[toneFor(form, submitter)] || tones.neutral
  const confirmButton = dialog.querySelector("[data-role=confirm]")
  const cancelButton = dialog.querySelector("[data-role=cancel]")

  dialog.querySelector("[data-role=message]").textContent = message
  dialog.querySelector("[data-role=icon]").textContent = tone.icon
  dialog.querySelector("[data-role=icon-box]").className = `flex h-12 w-12 items-center justify-center rounded-2xl ${tone.iconBox}`
  confirmButton.className = `min-h-12 rounded-full px-6 font-semibold text-white shadow-sm transition-all duration-200 ease-out active:scale-95 ${tone.confirm}`
  dialog.returnValue = "cancel"
  dialog.showModal()
  // Las acciones destructivas inician en "Cancelar" para evitar confirmaciones accidentales.
  ;(tone === tones.danger ? cancelButton : confirmButton).focus()

  return new Promise((resolve) => {
    dialog.addEventListener("close", () => resolve(dialog.returnValue === "confirm"), { once: true })
  })
}

if (Turbo.config?.forms) {
  Turbo.config.forms.confirm = confirmDialog
} else {
  Turbo.setConfirmMethod(confirmDialog)
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["instruction", "item", "incompatible", "selectionError"]

  connect() {
    this.filter()
  }

  filter() {
    const option = this.instructionTarget.selectedOptions[0]
    this.itemTargets.forEach((item, index) => {
      const criterion = option?.dataset.criterion
      const compatible = option &&
        (criterion !== "quantity" || option.dataset.packagingId === item.dataset.packagingId) &&
        (criterion !== "weight" || item.dataset.hasWeight === "true") &&
        (!["all", "half"].includes(criterion) || option.dataset.containerId === item.dataset.containerId) &&
        !item.dataset.allocatedInstructionIds.split(",").includes(option.value)
      item.disabled = !compatible
      if (!compatible) item.checked = false
      this.incompatibleTargets[index].hidden = !!compatible
    })
  }

  validate(event) {
    if (this.itemTargets.some((item) => item.checked && !item.disabled)) return

    event.preventDefault()
    this.selectionErrorTarget.hidden = false
    this.selectionErrorTarget.focus()
  }

  clearError() {
    this.selectionErrorTarget.hidden = true
  }
}

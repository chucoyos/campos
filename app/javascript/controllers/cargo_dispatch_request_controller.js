import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "client", "criterion", "preferredContainerOption", "preferredContainer",
    "quantity", "quantityInput", "weight", "weightInput"
  ]

  connect() {
    this.filterContainers()
    this.toggleCriterion()
  }

  filterContainers() {
    if (!this.hasPreferredContainerTarget) return

    const clientId = this.hasClientTarget ? this.clientTarget.value : null
    this.preferredContainerOptionTargets.forEach((option) => {
      const checkbox = option.querySelector("input")
      const hidden = clientId !== null && (clientId === "" || checkbox.dataset.clientId !== clientId)
      option.hidden = hidden
      checkbox.disabled = hidden
      if (hidden) checkbox.checked = false
    })
  }

  toggleCriterion() {
    if (!this.hasCriterionTarget) return

    const quantity = this.criterionTarget.value === "quantity"
    this.setField(this.quantityTarget, this.quantityInputTarget, quantity)
    this.setField(this.weightTarget, this.weightInputTarget, !quantity)
  }

  setField(wrapper, input, visible) {
    wrapper.hidden = !visible
    input.disabled = !visible
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "slotId", "result", "selected", "empty", "submit" ]
  static values = { selectPrompt: String }

  connect() {
    this.filter()
  }

  filter() {
    const query = this.inputTarget.value.trim().toLocaleLowerCase()
    this.slotIdTarget.value = ""
    this.selectedTarget.textContent = this.selectPromptValue
    this.submitTarget.disabled = true
    let visible = 0

    this.resultTargets.forEach((result) => {
      const matches = query.length > 0 ? result.dataset.search.includes(query) : result.dataset.source !== "yard"
      result.hidden = !matches || visible >= 15
      if (matches) visible += 1
    })
    this.emptyTarget.hidden = visible > 0
  }

  choose(event) {
    const result = event.currentTarget
    this.slotIdTarget.value = result.dataset.slotId
    this.inputTarget.value = result.dataset.label
    this.selectedTarget.textContent = result.dataset.label
    this.submitTarget.disabled = false
    this.resultTargets.forEach((item) => { item.hidden = true })
    this.emptyTarget.hidden = true
  }
}

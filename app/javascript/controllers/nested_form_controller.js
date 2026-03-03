import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template", "container"]

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime())
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  remove(event) {
    event.preventDefault()
    const item = event.target.closest("[data-nested-form-target='item']")
    if (item) {
      const destroyInput = item.querySelector("input[name*='_destroy']")
      if (destroyInput) {
        destroyInput.value = "1"
        item.classList.add("hidden")
      } else {
        item.remove()
      }
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["snoozeDropdown"]

  toggleSnooze(event) {
    event.stopPropagation()
    this.snoozeDropdownTarget.classList.toggle("hidden")
  }

  closeSnooze(event) {
    if (!this.element.contains(event.target)) {
      this.snoozeDropdownTarget.classList.add("hidden")
    }
  }

  connect() {
    this._closeHandler = this.closeSnooze.bind(this)
    document.addEventListener("click", this._closeHandler)
  }

  disconnect() {
    document.removeEventListener("click", this._closeHandler)
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event) {
    const parent = event.currentTarget.closest("[data-children]")
    if (!parent) return

    const childIds = parent.dataset.children.split(",")
    childIds.forEach(id => {
      const child = document.getElementById(id)
      if (child) {
        child.classList.toggle("hidden")
      }
    })
  }
}

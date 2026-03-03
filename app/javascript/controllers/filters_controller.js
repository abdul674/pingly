import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]

  filter() {
    const params = new URLSearchParams(window.location.search)

    if (this.hasStatusTarget && this.statusTarget.value) {
      params.set("status", this.statusTarget.value)
    } else {
      params.delete("status")
    }

    const url = `${window.location.pathname}?${params.toString()}`
    Turbo.visit(url)
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { refresh: Boolean }

  connect() {
    if (this.refreshValue) {
      this.scheduleRefresh()
    }
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  scheduleRefresh() {
    this.timeout = setTimeout(() => {
      this.element.reload()
    }, 3000)
  }
}

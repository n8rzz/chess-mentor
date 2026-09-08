import { Controller } from "@hotwired/stimulus"

// Reloads the nearest Turbo Frame on an interval while `refresh` is true.
// Controller must live *inside* the frame so each reload can start/stop
// polling from the latest server-rendered refresh value.
export default class extends Controller {
  static values = {
    refresh: Boolean,
    interval: { type: Number, default: 3000 },
    src: String
  }

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
      const frame = this.element.closest("turbo-frame")
      if (!frame) return

      const src = this.hasSrcValue ? this.srcValue : window.location.href

      // reload() is a no-op without src. After the first load Turbo may store an
      // absolute URL, so re-assigning the relative src alone will not refetch.
      if (frame.hasAttribute("src")) {
        frame.reload()
      } else {
        frame.src = src
      }
    }, this.intervalValue)
  }
}

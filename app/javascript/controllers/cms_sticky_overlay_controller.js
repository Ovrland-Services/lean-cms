import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay"]

  connect() {
    this.isStuck = false
    this.scrollHandler = this.handleScroll.bind(this)
  }

  mouseEnter() {
    window.addEventListener("scroll", this.scrollHandler)
    this.handleScroll()
  }

  mouseLeave() {
    window.removeEventListener("scroll", this.scrollHandler)
    this.unstick()
  }

  handleScroll() {
    const containerRect = this.element.getBoundingClientRect()
    const naturalOffset = 12 // Standard offset from container top (don't use CSS top which varies)
    const stickyTop = 140 // Must clear header + admin bar
    const buffer = 20 // Hysteresis buffer to prevent flickering

    // Calculate where the overlay would naturally be positioned
    const naturalTop = containerRect.top + naturalOffset

    // Stick when the overlay's natural position would be above the sticky position
    // Use different thresholds for stick vs unstick to prevent flickering
    if (!this.isStuck && naturalTop < stickyTop) {
      this.stick()
    } else if (this.isStuck && naturalTop > stickyTop + buffer) {
      this.unstick()
    }
  }

  stick() {
    if (!this.isStuck) {
      const rect = this.overlayTarget.getBoundingClientRect()
      this.overlayTarget.style.left = `${rect.left}px`
      this.overlayTarget.classList.add("cms-overlay-stuck")
      this.isStuck = true
    }
  }

  unstick() {
    if (this.isStuck) {
      this.overlayTarget.classList.remove("cms-overlay-stuck")
      this.overlayTarget.style.left = ""
      this.isStuck = false
    }
  }

  disconnect() {
    window.removeEventListener("scroll", this.scrollHandler)
  }
}

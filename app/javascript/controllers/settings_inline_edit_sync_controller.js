import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]

  connect() {
    // Sync the checkbox state with localStorage on load
    const isEnabled = localStorage.getItem('cms-inline-editing-enabled')
    if (isEnabled !== null) {
      this.checkboxTarget.checked = isEnabled === 'true'
    }
  }

  toggle(event) {
    const enabled = event.target.checked
    
    // Update localStorage to match the settings page toggle
    localStorage.setItem('cms-inline-editing-enabled', enabled.toString())
    
    // Show feedback
    this.showFeedback(enabled ? 'Inline editing will be enabled after save' : 'Inline editing will be disabled after save')
  }

  showFeedback(message) {
    const feedback = document.createElement('div')
    feedback.textContent = message
    feedback.className = 'fixed top-4 right-4 bg-gray-800 text-white px-4 py-2 rounded shadow-lg z-[70] transition-opacity'
    feedback.style.opacity = '0'
    
    document.body.appendChild(feedback)
    
    setTimeout(() => { feedback.style.opacity = '1' }, 10)
    setTimeout(() => {
      feedback.style.opacity = '0'
      setTimeout(() => { feedback.remove() }, 300)
    }, 3000)
  }
}

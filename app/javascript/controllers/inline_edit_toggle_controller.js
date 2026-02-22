import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]

  connect() {
    // Check localStorage for saved preference (default to true)
    const isEnabled = localStorage.getItem('cms-inline-editing-enabled')
    const enabled = isEnabled === null ? true : isEnabled === 'true'
    
    this.checkboxTarget.checked = enabled
    this.updateIconsVisibility(enabled)
  }

  toggle(event) {
    const enabled = event.target.checked
    
    // Save preference to localStorage
    localStorage.setItem('cms-inline-editing-enabled', enabled.toString())
    
    // Update visibility of all inline edit icons
    this.updateIconsVisibility(enabled)
    
    // Show a brief feedback message
    this.showFeedback(enabled ? 'Inline editing enabled' : 'Inline editing disabled')
  }

  updateIconsVisibility(enabled) {
    // Find all inline edit icon containers
    const iconContainers = document.querySelectorAll('.cms-inline-edit-icons')
    
    iconContainers.forEach(container => {
      if (enabled) {
        container.style.display = ''
      } else {
        container.style.display = 'none'
      }
    })
    
    // Toggle class on body to control all CMS editing UI
    if (enabled) {
      document.body.classList.remove('cms-inline-editing-disabled')
    } else {
      document.body.classList.add('cms-inline-editing-disabled')
    }
    
    // Also toggle the disabled class on editable sections (for dotted borders)
    const editableSections = document.querySelectorAll('.cms-editable-section')
    
    editableSections.forEach(section => {
      if (enabled) {
        section.classList.remove('cms-inline-editing-disabled')
      } else {
        section.classList.add('cms-inline-editing-disabled')
      }
    })
  }

  showFeedback(message) {
    // Create a temporary feedback message
    const feedback = document.createElement('div')
    feedback.textContent = message
    feedback.className = 'fixed top-12 right-6 bg-gray-800 text-white px-4 py-2 rounded shadow-lg z-[70] transition-opacity'
    feedback.style.opacity = '0'
    
    document.body.appendChild(feedback)
    
    // Fade in
    setTimeout(() => {
      feedback.style.opacity = '1'
    }, 10)
    
    // Fade out and remove after 2 seconds
    setTimeout(() => {
      feedback.style.opacity = '0'
      setTimeout(() => {
        feedback.remove()
      }, 300)
    }, 2000)
  }
}

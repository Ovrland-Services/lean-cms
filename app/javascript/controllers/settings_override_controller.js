import { Controller } from "@hotwired/stimulus"

// Handles the override toggle for settings-based page content
// Shows/hides the edit form and saves the override preference
export default class extends Controller {
  static targets = ["checkbox", "form"]
  static values = { section: String }

  connect() {
    this.updateFormVisibility()
  }

  toggle(event) {
    const isChecked = event.target.checked
    const settingsKey = this.sectionValue === 'info' ? 'contact_info_override' : 'contact_hours_override'

    // Save the setting via AJAX
    fetch('/lean-cms/settings/update_override', {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        key: settingsKey,
        value: isChecked ? 'true' : 'false'
      })
    }).then(response => {
      if (response.ok) {
        this.updateFormVisibility()
      }
    })
  }

  updateFormVisibility() {
    if (this.hasFormTarget) {
      const isChecked = this.checkboxTarget.checked
      if (isChecked) {
        this.formTarget.classList.remove('hidden')
      } else {
        this.formTarget.classList.add('hidden')
      }
    }
  }
}

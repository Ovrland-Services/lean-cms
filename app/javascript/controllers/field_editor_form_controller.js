import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async handleSubmit(event) {
    event.preventDefault()

    const form = event.target
    const formData = new FormData(form)
    const fieldId = form.action.match(/\/page-contents\/field\/(\d+)/)[1]

    // Handle bullets special case
    const bulletsFieldId = formData.get('bullets_field_id')
    if (bulletsFieldId) {
      const bulletItems = formData.getAll('bullet_items[]').filter(item => item.trim() !== '')
      formData.delete('bullets_field_id')
      formData.delete('bullet_items[]')
      formData.set('value', JSON.stringify(bulletItems))
    }

    // Handle cards - get the JSON from the hidden input and add file inputs
    const cardsValue = formData.get('value')
    if (cardsValue && cardsValue.startsWith('[')) {
      // Already JSON, keep it
      // Add file inputs for card images
      const cardsEditor = this.application.getControllerForElementAndIdentifier(
        form.querySelector('[data-controller*="cards-editor"]'),
        "cards-editor"
      )
      if (cardsEditor && cardsEditor.pendingImages) {
        Object.keys(cardsEditor.pendingImages).forEach(index => {
          const file = cardsEditor.pendingImages[index]
          formData.append(`card_images[${index}]`, file)
        })
      }
    } else if (cardsValue) {
      // Try to parse if it's a string
      try {
        JSON.parse(cardsValue)
      } catch (e) {
        // Not JSON, keep as is
      }
    }

    try {
      const response = await fetch(form.action, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: formData
      })

      const data = await response.json()

      if (data.success) {
        // Close modal and reload page to show updated content
        const modalEvent = new CustomEvent('cms:close-field-editor')
        window.dispatchEvent(modalEvent)
        window.location.reload()
      } else {
        alert('Error: ' + (data.errors ? data.errors.join(', ') : 'Failed to save'))
      }
    } catch (error) {
      alert('Failed to save: ' + error.message)
    }
  }
}


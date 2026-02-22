import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cardsList", "hiddenInput"]
  static values = { initial: String }

  connect() {
    // Parse initial cards from JSON
    try {
      this.cards = JSON.parse(this.initialValue || '[]')
    } catch (e) {
      console.error('Failed to parse initial cards:', e)
      this.cards = []
    }
    
    // Store temporary image files for upload
    this.pendingImages = {}
    
    console.log('Cards editor initialized with:', this.cards)
    this.render()
  }

  addCard() {
    this.cards.push({
      icon: 'gear',
      icon_color: 'white',
      bg_color: '',
      heading: '',
      text: '',
      alignment: 'left',
      use_image: false,
      image_id: null,
      image_preview: null
    })
    this.render()
  }

  removeCard(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.cards.splice(index, 1)
    this.render()
  }

  updateCard(event) {
    const input = event.currentTarget
    const index = parseInt(input.dataset.index)
    const field = input.dataset.field
    
    if (field === 'use_image') {
      this.cards[index][field] = input.checked
      this.render()
    } else {
      this.cards[index][field] = input.value
      this.updateHiddenInput()

      // Keep the color swatch in sync when the user types a valid hex value
      if ((field === 'bg_color' || field === 'icon_color') && /^#[0-9a-f]{6}$/i.test(input.value)) {
        const swatch = this.cardsListTarget.querySelector(
          `input[type="color"][data-index="${index}"][data-field="${field}"]`
        )
        if (swatch) swatch.value = input.value
      }
    }
  }

  updateColorPicker(event) {
    const swatch = event.currentTarget
    const index = parseInt(swatch.dataset.index)
    const field = swatch.dataset.field
    const value = swatch.value

    this.cards[index][field] = value
    this.updateHiddenInput()

    // Keep the text input in sync
    const textInput = this.cardsListTarget.querySelector(
      `input[type="text"][data-index="${index}"][data-field="${field}"]`
    )
    if (textInput) textInput.value = value
  }

  handleImageUpload(event) {
    const input = event.currentTarget
    const index = parseInt(input.dataset.index)
    const file = input.files[0]
    
    if (!file) return
    
    // Store file for later upload
    this.pendingImages[index] = file
    
    // Create preview URL
    const reader = new FileReader()
    reader.onload = (e) => {
      this.cards[index].image_preview = e.target.result
      this.render()
    }
    reader.readAsDataURL(file)
  }

  render() {
    if (this.cards.length === 0) {
      this.cardsListTarget.innerHTML = `
        <div class="text-sm text-gray-500 py-4 text-center">
          No cards yet. Click "Add Card" to create one.
        </div>
      `
    } else {
      this.cardsListTarget.innerHTML = this.cards.map((card, index) => this.renderCard(card, index)).join('')
    }
    
    this.updateHiddenInput()
  }

  renderCard(card, index) {
    const useImage = card.use_image === true || card.use_image === 'true'
    const hasImagePreview = card.image_preview || (card.image_id && card.image_url)
    
    return `
      <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
        <div class="flex items-center justify-between mb-3">
          <h4 class="font-semibold text-gray-900">Card ${index + 1}</h4>
          <button type="button" 
                  data-action="click->cards-editor#removeCard"
                  data-index="${index}"
                  class="text-red-600 hover:text-red-800 text-sm font-medium cursor-pointer">
            Remove
          </button>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <!-- Use Image Toggle -->
          <div class="col-span-2">
            <label class="flex items-center">
              <input type="checkbox"
                     ${useImage ? 'checked' : ''}
                     data-action="change->cards-editor#updateCard"
                     data-index="${index}"
                     data-field="use_image"
                     class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 focus:ring-2">
              <span class="ml-2 text-xs font-medium text-gray-700">Use uploaded image instead of icon</span>
            </label>
          </div>

          ${useImage ? `
          <!-- Image Upload -->
          <div class="col-span-2">
            <label class="block text-xs font-medium text-gray-700 mb-1">Image</label>
            ${hasImagePreview ? `
              <div class="mb-2">
                <img src="${card.image_preview || card.image_url}" 
                     alt="Preview" 
                     class="max-w-xs h-32 object-contain border border-gray-300 rounded-lg">
              </div>
            ` : ''}
            <input type="file"
                   accept="image/*"
                   data-action="change->cards-editor#handleImageUpload"
                   data-index="${index}"
                   class="block w-full text-sm text-gray-900 border border-gray-300 rounded-lg cursor-pointer bg-gray-50 focus:outline-none">
            <p class="text-xs text-gray-500 mt-1">Upload an image for this card</p>
          </div>
          ` : `
          <!-- Icon -->
          <div>
            <label class="block text-xs font-medium text-gray-700 mb-1">Icon</label>
            <select data-action="change->cards-editor#updateCard"
                    data-index="${index}"
                    data-field="icon"
                    class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              ${this.renderIconOptions(card.icon)}
            </select>
          </div>

          <!-- Icon Color -->
          <div>
            <label class="block text-xs font-medium text-gray-700 mb-1">Icon Color</label>
            ${this.renderColorInput(card.icon_color, index, 'icon_color', '#000000 or white')}
          </div>
          `}

          <!-- Background Color -->
          <div>
            <label class="block text-xs font-medium text-gray-700 mb-1">Background Color</label>
            ${this.renderColorInput(card.bg_color, index, 'bg_color', '#ffffff or gradient-red')}
          </div>

          <!-- Alignment -->
          <div>
            <label class="block text-xs font-medium text-gray-700 mb-1">Alignment</label>
            <select data-action="change->cards-editor#updateCard"
                    data-index="${index}"
                    data-field="alignment"
                    class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              ${this.renderAlignmentOptions(card.alignment)}
            </select>
          </div>

          <!-- Heading -->
          <div class="col-span-2">
            <label class="block text-xs font-medium text-gray-700 mb-1">Heading</label>
            <input type="text" 
                   value="${this.escapeHtml(card.heading || '')}"
                   data-action="input->cards-editor#updateCard"
                   data-index="${index}"
                   data-field="heading"
                   class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                   placeholder="Card heading">
          </div>

          <!-- Text -->
          <div class="col-span-2">
            <label class="block text-xs font-medium text-gray-700 mb-1">Text</label>
            <textarea data-action="input->cards-editor#updateCard"
                      data-index="${index}"
                      data-field="text"
                      rows="2"
                      class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"
                      placeholder="Card description">${this.escapeHtml(card.text || '')}</textarea>
          </div>
        </div>
      </div>
    `
  }

  renderIconOptions(selected) {
    const icons = [
      'checkmark-badge',
      'checkmark-circle',
      'lock',
      'lightning-bolt',
      'users',
      'sliders',
      'globe',
      'support',
      'control-panel',
      'gear'
    ]
    
    return icons.map(icon => 
      `<option value="${icon}" ${icon === selected ? 'selected' : ''}>${this.humanize(icon)}</option>`
    ).join('')
  }

  renderAlignmentOptions(selected) {
    const alignments = ['left', 'center', 'right']
    
    return alignments.map(align => 
      `<option value="${align}" ${align === selected ? 'selected' : ''}>${this.capitalize(align)}</option>`
    ).join('')
  }

  updateHiddenInput() {
    // Clean up cards data before saving (remove preview URLs, keep only IDs)
    const cleanedCards = this.cards.map(card => {
      const cleaned = { ...card }
      // Remove preview URL from saved data (it's only for display)
      if (cleaned.image_preview) {
        delete cleaned.image_preview
      }
      // Remove image_url if present (server will provide this)
      if (cleaned.image_url) {
        delete cleaned.image_url
      }
      return cleaned
    })
    this.hiddenInputTarget.value = JSON.stringify(cleanedCards)
  }

  // Get pending image files for form submission
  getPendingImages() {
    return this.pendingImages
  }

  renderColorInput(value, index, field, placeholder = '') {
    const safeValue = this.escapeHtml(value || '')
    // Only pre-fill the swatch if the value is already a valid 6-digit hex
    const isHex = /^#[0-9a-f]{6}$/i.test(value || '')
    const swatchValue = isHex ? value : '#ffffff'

    return `
      <div class="flex items-center gap-2">
        <input type="color"
               value="${swatchValue}"
               data-action="input->cards-editor#updateColorPicker"
               data-index="${index}"
               data-field="${field}"
               title="Pick a color"
               class="cards-color-swatch">
        <input type="text"
               value="${safeValue}"
               data-action="input->cards-editor#updateCard"
               data-index="${index}"
               data-field="${field}"
               class="flex-1 px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
               placeholder="${placeholder}">
      </div>
    `
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  humanize(str) {
    return str.split('-').map(word => 
      word.charAt(0).toUpperCase() + word.slice(1)
    ).join(' ')
  }

  capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1)
  }
}


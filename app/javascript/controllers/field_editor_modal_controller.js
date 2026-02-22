import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "content", "loader"]

  connect() {
    // Listen for open modal events
    window.addEventListener('cms:open-field-editor', this.handleOpenModal.bind(this))
    // Listen for close modal events
    window.addEventListener('cms:close-field-editor', this.close.bind(this))
  }

  disconnect() {
    window.removeEventListener('cms:open-field-editor', this.handleOpenModal.bind(this))
    window.removeEventListener('cms:close-field-editor', this.close.bind(this))
  }

  async handleOpenModal(event) {
    const { fieldId, type, page, section, key } = event.detail

    this.showModal()
    this.showLoader()

    try {
      // Fetch the editor form via AJAX
      const response = await fetch(`/lean-cms/page-contents/field/${fieldId}/edit`, {
        headers: {
          'Accept': 'text/html'
        }
      })

      if (response.ok) {
        const html = await response.text()
        this.contentTarget.innerHTML = html
        this.hideLoader()
      } else {
        throw new Error('Failed to load editor')
      }
    } catch (error) {
      this.showError('Failed to load editor')
      setTimeout(() => this.close(), 2000)
    }
  }

  showModal() {
    this.modalTarget.classList.remove('hidden')
    document.body.style.overflow = 'hidden'
  }

  hideLoader() {
    this.loaderTarget.classList.add('hidden')
  }

  showLoader() {
    this.loaderTarget.classList.remove('hidden')
  }

  showError(message) {
    this.contentTarget.innerHTML = `
      <div class="p-8 text-center text-red-600">
        ${message}
      </div>
    `
    this.hideLoader()
  }

  close() {
    this.modalTarget.classList.add('hidden')
    document.body.style.overflow = ''
    this.contentTarget.innerHTML = ''
  }

  handleBackdropClick(event) {
    if (event.target === event.currentTarget) {
      this.close()
    }
  }
}


import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    fieldId: Number,
    type: String,
    inline: Boolean,
    page: String,
    section: String,
    key: String
  }


  connect() {
    this.addEditIcon()
    // Extract text content, stripping any HTML tags
    this.originalValue = this.element.textContent.trim()
    // Store the blur handler reference so we can remove it
    this.blurHandler = null
    this.isEditing = false
  }

  addEditIcon() {
    // Create edit icon container
    const iconContainer = document.createElement('span')
    iconContainer.className = 'cms-inline-edit-icons'
    
    // Check if inline editing is enabled (default to true)
    const isEnabled = localStorage.getItem('cms-inline-editing-enabled')
    const enabled = isEnabled === null ? true : isEnabled === 'true'
    if (!enabled) {
      iconContainer.style.display = 'none'
    }
    
    // Create edit icon
    const editIcon = document.createElement('span')
    editIcon.className = 'cms-inline-edit-icon cms-edit-icon-edit'
    editIcon.innerHTML = `
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/>
      </svg>
    `
    editIcon.addEventListener('click', (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.handleEdit()
    })
    
    // Create undo icon
    const undoIcon = document.createElement('span')
    undoIcon.className = 'cms-inline-edit-icon cms-edit-icon-undo'
    undoIcon.title = 'Undo last change'
    undoIcon.innerHTML = `
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6"/>
      </svg>
    `
    undoIcon.addEventListener('click', (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.undoLastChange()
    })
    
    iconContainer.appendChild(editIcon)
    iconContainer.appendChild(undoIcon)
    this.element.appendChild(iconContainer)
    // Store reference to icon container so we can remove it later if needed
    this.iconContainer = iconContainer
  }

  handleEdit() {
    if (this.inlineValue) {
      this.startInlineEdit()
    } else {
      this.openModal()
    }
  }

  startInlineEdit() {
    const value = this.element.textContent.trim()
    const useTextarea = value.length > 80

    // Build modal DOM
    const overlay = document.createElement('div')
    overlay.className = 'cms-text-edit-overlay'

    const dialog = document.createElement('div')
    dialog.className = 'cms-text-edit-dialog'

    // Header
    const header = document.createElement('div')
    header.className = 'cms-text-edit-header'
    header.innerHTML = `
      <span class="cms-text-edit-label">Edit Text</span>
      <button type="button" class="cms-text-edit-close" aria-label="Close">
        <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
        </svg>
      </button>
    `

    // Input
    let input
    if (useTextarea) {
      input = document.createElement('textarea')
      input.rows = 4
      input.className = 'cms-text-edit-input'
    } else {
      input = document.createElement('input')
      input.type = 'text'
      input.className = 'cms-text-edit-input'
    }
    input.value = value

    // Footer buttons
    const footer = document.createElement('div')
    footer.className = 'cms-text-edit-footer'
    footer.innerHTML = `
      <button type="button" class="cms-text-edit-btn cms-text-edit-btn-cancel">Cancel</button>
      <button type="button" class="cms-text-edit-btn cms-text-edit-btn-save">Save</button>
    `

    dialog.appendChild(header)
    dialog.appendChild(input)
    dialog.appendChild(footer)
    overlay.appendChild(dialog)
    document.body.appendChild(overlay)

    input.focus()
    useTextarea ? input.setSelectionRange(0, input.value.length) : input.select()

    this.isEditing = true
    this._activeOverlay = overlay

    const close = () => {
      overlay.remove()
      this.isEditing = false
      this._activeOverlay = null
    }

    const save = () => {
      this.saveInlineFromDialog(input.value.trim(), close)
    }

    footer.querySelector('.cms-text-edit-btn-save').addEventListener('click', save)
    footer.querySelector('.cms-text-edit-btn-cancel').addEventListener('click', close)
    header.querySelector('.cms-text-edit-close').addEventListener('click', close)

    // Close on backdrop click
    overlay.addEventListener('click', (e) => { if (e.target === overlay) close() })

    // Keyboard shortcuts
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') { close() }
      else if (e.key === 'Enter' && (!useTextarea || e.ctrlKey || e.metaKey)) {
        e.preventDefault()
        save()
      }
    })
  }

  async saveInlineFromDialog(newValue, closeFn) {
    if (newValue === this.originalValue) { closeFn(); return }

    const saveBtn = this._activeOverlay?.querySelector('.cms-text-edit-btn-save')
    if (saveBtn) { saveBtn.textContent = 'Saving…'; saveBtn.disabled = true }

    try {
      const response = await fetch(`/lean-cms/page-contents/field/${this.fieldIdValue}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ value: newValue })
      })

      const data = await response.json()

      if (data.success) {
        this.originalValue = newValue
        this.element.innerHTML = ''
        this.element.textContent = newValue
        void this.element.offsetHeight
        this.addEditIcon()
        this.showFeedback('Saved!', 'success')
        closeFn()
      } else {
        this.showFeedback('Error: ' + data.errors.join(', '), 'error')
        if (saveBtn) { saveBtn.textContent = 'Save'; saveBtn.disabled = false }
      }
    } catch (error) {
      this.showFeedback('Save failed', 'error')
      if (saveBtn) { saveBtn.textContent = 'Save'; saveBtn.disabled = false }
    }
  }

  openModal() {
    // Dispatch custom event that modal controller will listen for
    const event = new CustomEvent('cms:open-field-editor', {
      detail: {
        fieldId: this.fieldIdValue,
        type: this.typeValue,
        page: this.pageValue,
        section: this.sectionValue,
        key: this.keyValue
      }
    })
    window.dispatchEvent(event)
  }

  async undoLastChange() {
    // Fetch the preview first so we can show a diff
    let preview = null
    try {
      const res = await fetch(`/lean-cms/page-contents/field/${this.fieldIdValue}/undo/preview`, {
        headers: { 'Accept': 'application/json' }
      })
      if (res.ok) preview = await res.json()
    } catch (_) {
      // If preview fails, fall back to generic confirm
    }

    if (preview && preview.success) {
      this.showUndoDiffDialog(preview.current_value, preview.previous_value)
    } else {
      this.showConfirmDialog({
        title: 'Undo Last Change',
        message: preview?.error || 'Revert this field to its previous value? This cannot be undone again.',
        confirmLabel: 'Yes, Undo',
        confirmClass: 'cms-text-edit-btn-danger',
        onConfirm: () => this.performUndo()
      })
    }
  }

  showUndoDiffDialog(currentValue, previousValue) {
    const { oldHtml, newHtml } = this.diffWords(currentValue, previousValue)

    const overlay = document.createElement('div')
    overlay.className = 'cms-text-edit-overlay'

    const dialog = document.createElement('div')
    dialog.className = 'cms-text-edit-dialog cms-confirm-dialog'

    dialog.innerHTML = `
      <div class="cms-text-edit-header">
        <span class="cms-text-edit-label">Undo Last Change</span>
        <button type="button" class="cms-text-edit-close" aria-label="Close">
          <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>
      <div class="cms-diff-block">
        <div class="cms-diff-row cms-diff-row-current">
          <span class="cms-diff-label">Current</span>
          <span class="cms-diff-value">${oldHtml}</span>
        </div>
        <div class="cms-diff-row cms-diff-row-previous">
          <span class="cms-diff-label">Reverts to</span>
          <span class="cms-diff-value">${newHtml}</span>
        </div>
      </div>
      <div class="cms-text-edit-footer">
        <button type="button" class="cms-text-edit-btn cms-text-edit-btn-cancel">Cancel</button>
        <button type="button" class="cms-text-edit-btn cms-text-edit-btn-danger">Yes, Undo</button>
      </div>
    `

    overlay.appendChild(dialog)
    document.body.appendChild(overlay)

    const close = () => overlay.remove()

    dialog.querySelector('.cms-text-edit-close').addEventListener('click', close)
    dialog.querySelector('.cms-text-edit-btn-cancel').addEventListener('click', close)
    dialog.querySelector('.cms-text-edit-btn-danger').addEventListener('click', () => {
      close()
      this.performUndo()
    })
    overlay.addEventListener('click', (e) => { if (e.target === overlay) close() })
    document.addEventListener('keydown', function handler(e) {
      if (e.key === 'Escape') { close(); document.removeEventListener('keydown', handler) }
    })
  }

  // Word-level diff using LCS — returns { oldHtml, newHtml } with <del>/<ins> markup
  diffWords(oldText, newText) {
    const escape = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')

    if (oldText === newText) {
      const e = escape(oldText)
      return { oldHtml: e, newHtml: e }
    }

    // Split preserving whitespace tokens so spacing is maintained
    const tokenize = (s) => s.split(/(\s+)/)
    const a = tokenize(oldText)
    const b = tokenize(newText)
    const m = a.length, n = b.length

    // Build LCS DP table
    const dp = Array.from({ length: m + 1 }, () => new Uint16Array(n + 1))
    for (let i = 1; i <= m; i++) {
      for (let j = 1; j <= n; j++) {
        dp[i][j] = a[i - 1] === b[j - 1] ? dp[i - 1][j - 1] + 1 : Math.max(dp[i - 1][j], dp[i][j - 1])
      }
    }

    // Backtrack to produce ops
    const ops = []
    let i = m, j = n
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && a[i - 1] === b[j - 1]) {
        ops.unshift({ type: 'equal', val: a[i - 1] }); i--; j--
      } else if (j > 0 && (i === 0 || dp[i][j - 1] >= dp[i - 1][j])) {
        ops.unshift({ type: 'insert', val: b[j - 1] }); j--
      } else {
        ops.unshift({ type: 'delete', val: a[i - 1] }); i--
      }
    }

    let oldHtml = '', newHtml = ''
    for (const op of ops) {
      const e = escape(op.val)
      if (op.type === 'equal')        { oldHtml += e;                          newHtml += e }
      else if (op.type === 'delete')  { oldHtml += `<del>${e}</del>` }
      else                            { newHtml += `<ins>${e}</ins>` }
    }

    return { oldHtml, newHtml }
  }

  async performUndo() {
    try {
      const response = await fetch(`/lean-cms/page-contents/field/${this.fieldIdValue}/undo`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (!response.ok) {
        this.showFeedback('Error: Server returned ' + response.status, 'error')
        return
      }

      const data = await response.json()

      if (data.success) {
        this.originalValue = data.value
        this.element.innerHTML = ''
        this.element.textContent = data.value
        void this.element.offsetHeight
        this.addEditIcon()
        this.showFeedback('Undone!', 'success')
      } else {
        this.showFeedback('Error: ' + (data.error || 'Could not undo'), 'error')
      }
    } catch (error) {
      this.showFeedback('Undo failed: ' + error.message, 'error')
    }
  }

  showConfirmDialog({ title, message, confirmLabel = 'Confirm', confirmClass = 'cms-text-edit-btn-save', onConfirm }) {
    const overlay = document.createElement('div')
    overlay.className = 'cms-text-edit-overlay'

    overlay.innerHTML = `
      <div class="cms-text-edit-dialog cms-confirm-dialog">
        <div class="cms-text-edit-header">
          <span class="cms-text-edit-label">${title}</span>
          <button type="button" class="cms-text-edit-close" aria-label="Close">
            <svg width="16" height="16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
        <p class="cms-confirm-message">${message}</p>
        <div class="cms-text-edit-footer">
          <button type="button" class="cms-text-edit-btn cms-text-edit-btn-cancel">Cancel</button>
          <button type="button" class="cms-text-edit-btn ${confirmClass}">${confirmLabel}</button>
        </div>
      </div>
    `

    document.body.appendChild(overlay)

    const close = () => overlay.remove()

    overlay.querySelector('.cms-text-edit-close').addEventListener('click', close)
    overlay.querySelector('.cms-text-edit-btn-cancel').addEventListener('click', close)
    overlay.querySelector(`.${confirmClass}`).addEventListener('click', () => {
      close()
      onConfirm()
    })
    overlay.addEventListener('click', (e) => { if (e.target === overlay) close() })
    document.addEventListener('keydown', function handler(e) {
      if (e.key === 'Escape') { close(); document.removeEventListener('keydown', handler) }
    })
  }

  showFeedback(message, type) {
    const feedback = document.createElement('div')
    feedback.className = `cms-inline-feedback cms-inline-feedback-${type}`
    feedback.textContent = message
    this.element.appendChild(feedback)

    setTimeout(() => feedback.remove(), 2000)
  }
}


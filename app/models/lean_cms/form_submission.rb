module LeanCms
  class FormSubmission < ApplicationRecord
    self.table_name = 'lean_cms_form_submissions'

    has_paper_trail

    validates :form_type, presence: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

    enum :status, { new_submission: 0, read: 1, replied: 2, archived: 3 }

    scope :recent, -> { order(created_at: :desc) }
    scope :unread, -> { where(status: :new_submission) }
    scope :quote_requests, -> { where(form_type: 'quote_request') }

    # Mark as read
    def mark_as_read!
      update(status: :read)
    end

    # Mark as replied
    def mark_as_replied!
      update(status: :replied)
    end

    # Get all form data as hash
    def form_data
      {
        name: name,
        email: email,
        phone: phone,
        company_name: company_name,
        city: city,
        state: state,
        zip: zip,
        message: message
      }.merge(additional_data || {})
    end

    # Check if unread
    def unread?
      status == 'new_submission'
    end
  end
end

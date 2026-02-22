module LeanCms
  class FormSubmissionsController < LeanCms::ApplicationController
    skip_before_action :check_content_lock
    before_action :set_form_submission, only: [:show, :mark_as_read, :mark_as_replied, :destroy]

    def index
      @form_submissions = LeanCms::FormSubmission.recent
      @form_submissions = @form_submissions.where(form_type: params[:form_type]) if params[:form_type].present?
      @form_submissions = @form_submissions.where(status: params[:status]) if params[:status].present?
    end

    def show
      @form_submission.mark_as_read! if @form_submission.unread?
    end

    def mark_as_read
      @form_submission.mark_as_read!
      redirect_to lean_cms_form_submissions_path, notice: 'Submission marked as read.'
    end

    def mark_as_replied
      @form_submission.mark_as_replied!
      redirect_to lean_cms_form_submissions_path, notice: 'Submission marked as replied.'
    end

    def destroy
      @form_submission.destroy
      redirect_to lean_cms_form_submissions_path, notice: 'Submission deleted successfully.'
    end

    private

    def set_form_submission
      @form_submission = LeanCms::FormSubmission.find(params[:id])
    end
  end
end

class PagesController < ApplicationController
  # LeanCms::Authentication protects every controller by default. Opt the
  # public-facing demo pages out so non-admins can actually see them.
  allow_unauthenticated_access

  def home
    @page = LeanCms::Page.find_by(slug: 'home')
  end

  def about
    @page = LeanCms::Page.find_by(slug: 'about')
  end

  def contact
    @page = LeanCms::Page.find_by(slug: 'contact')
  end

  def submit_contact
    LeanCms::FormSubmission.create!(
      name:    params[:name],
      email:   params[:email],
      message: params[:message]
    )
    redirect_to contact_path, notice: "Message sent!"
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.message
    @page = LeanCms::Page.find_by(slug: 'contact')
    render :contact, status: :unprocessable_entity
  end
end

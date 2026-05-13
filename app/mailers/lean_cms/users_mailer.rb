module LeanCms
  class UsersMailer < LeanCms::ApplicationMailer
    def invitation(user, magic_link)
      @user = user
      @magic_link = magic_link
      @setup_url = lean_cms_password_setup_url(token: magic_link.token)
      @site_name = LeanCms.site_name

      mail(
        to: user.email_address,
        subject: "You've been invited to #{@site_name} CMS"
      )
    end

    def reactivation(user, magic_link)
      @user = user
      @magic_link = magic_link
      @setup_url = lean_cms_password_setup_url(token: magic_link.token)
      @site_name = LeanCms.site_name

      mail(
        to: user.email_address,
        subject: "Your #{@site_name} CMS account has been reactivated"
      )
    end

    def admin_triggered_password_reset(user, magic_link)
      @user = user
      @magic_link = magic_link
      @setup_url = lean_cms_password_setup_url(token: magic_link.token)
      @site_name = LeanCms.site_name

      mail(
        to: user.email_address,
        subject: "Password reset requested for #{@site_name} CMS"
      )
    end
  end
end

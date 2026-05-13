module LeanCms
  class << self
    attr_accessor :site_name,
                  :site_logo_path,
                  :primary_color,
                  :secondary_color,
                  :admin_path,
                  :user_class,
                  :posts_per_page,
                  :portfolio_enabled,
                  :mailer_from

    def configure
      yield self
    end
  end

  # Defaults
  self.site_name        = "My Site"
  self.site_logo_path   = nil
  self.primary_color    = "#2563eb"
  self.secondary_color  = "#1e40af"
  self.admin_path       = "/lean-cms"
  self.user_class       = "User"
  self.posts_per_page   = 10
  self.portfolio_enabled = true
  self.mailer_from      = "noreply@example.com"
end

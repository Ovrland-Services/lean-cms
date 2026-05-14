LeanCms.configure do |config|
  config.site_name       = "My Site"
  config.site_logo_path  = nil            # e.g. "logo.png" from app/assets/images
  config.primary_color   = "#2563eb"
  config.secondary_color = "#1e40af"
  config.admin_path      = "/lean-cms"
  config.user_class      = "<%= @user_class || 'User' %>"
  config.posts_per_page  = 10              # blog index pagination
  config.portfolio_enabled = true          # show the /portfolio routes + admin tab
  config.mailer_from     = "noreply@example.com"
end

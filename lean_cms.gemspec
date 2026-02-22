require_relative "lib/lean_cms/version"

Gem::Specification.new do |spec|
  spec.name        = "lean_cms"
  spec.version     = LeanCms::VERSION
  spec.authors     = ["OvrlandServices"]
  spec.email       = ["hello@ovrlandservices.com"]

  spec.summary     = "Lightweight Rails CMS with in-context editing for marketing sites."
  spec.description = "LeanCMS is a Rails Engine that adds in-context content editing, " \
                     "page content management, blog/portfolio, settings, and notifications " \
                     "to any Rails 8 application. Designed for SQLite-based marketing sites."
  spec.homepage    = "https://leancms.dev"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata = {
    "homepage_uri"    => "https://leancms.dev",
    "source_code_uri" => "https://github.com/OvrlandServices/lean-cms",
    "changelog_uri"   => "https://github.com/OvrlandServices/lean-cms/blob/main/CHANGELOG.md"
  }

  spec.files = Dir[
    "app/**/*",
    "config/**/*",
    "db/migrate/**/*",
    "lib/**/*",
    "LICENSE",
    "README.md",
    "CHANGELOG.md"
  ]

  spec.require_paths = ["lib"]

  # Rails engine
  spec.add_dependency "rails", ">= 8.0"

  # Core CMS dependencies
  spec.add_dependency "paper_trail"              # version tracking / undo
  spec.add_dependency "view_component"           # component-based views
  spec.add_dependency "kaminari"                 # pagination
  spec.add_dependency "pundit"                   # authorization policies
  spec.add_dependency "noticed", "~> 2.0"        # in-app + email/SMS notifications
  spec.add_dependency "image_processing", "~> 1.2" # ActiveStorage variants
  spec.add_dependency "meta-tags"                # SEO meta tag helpers
  spec.add_dependency "rack-attack"              # rate limiting
  spec.add_dependency "http"                     # HTTP client for notification delivery
end

require_relative "lib/lean_cms/version"

Gem::Specification.new do |spec|
  spec.name        = "lean_cms"
  spec.version     = LeanCms::VERSION
  spec.authors     = ["Matt Thompson"]
  spec.email       = ["matt@ovrland.io"]

  spec.summary     = "Lightweight Rails CMS with in-context editing for marketing sites."
  spec.description = "Lean CMS is a Rails Engine that adds in-context content editing, " \
                     "page content management, blog/portfolio, settings, and notifications " \
                     "to any Rails 8 application. Built for marketing sites — SQLite happy " \
                     "path with full Postgres/MySQL compatibility."
  spec.homepage    = "https://leancms.dev"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata = {
    "homepage_uri"      => "https://leancms.dev",
    "source_code_uri"   => "https://github.com/Ovrland-Services/lean-cms",
    "changelog_uri"     => "https://github.com/Ovrland-Services/lean-cms/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://leancms.dev/docs/",
    "bug_tracker_uri"   => "https://github.com/Ovrland-Services/lean-cms/issues"
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
  spec.add_dependency "rails", "~> 8.0"

  # Core CMS dependencies
  spec.add_dependency "paper_trail",     "~> 17.0"  # version tracking / undo
  spec.add_dependency "view_component",  "~> 4.0"   # component-based views
  spec.add_dependency "kaminari",        "~> 1.2"   # pagination
  spec.add_dependency "pundit",          "~> 2.5"   # authorization policies
  spec.add_dependency "noticed",         "~> 2.0"   # in-app + email/SMS notifications
  spec.add_dependency "image_processing", "~> 1.2"  # ActiveStorage variants
  spec.add_dependency "meta-tags",       "~> 2.20"  # SEO meta tag helpers
  spec.add_dependency "rack-attack",     "~> 6.7"   # rate limiting
  spec.add_dependency "http",            "~> 5.0"   # HTTP client for notification delivery
end

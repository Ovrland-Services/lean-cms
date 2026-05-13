require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_text/engine"

require "lean_cms"

module Dummy
  class Application < Rails::Application
    # Force root to the dummy app directory so config/database.yml resolves
    # correctly no matter where rake is invoked from.
    config.root = File.expand_path("..", __dir__)

    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.hosts.clear
    config.active_support.cache_format_version = 7.1

    # The dummy app does NOT use the gem's full bundle (no propshaft asset
    # pipeline, no importmaps, no tailwind) — only what the gem itself needs
    # at runtime for its models, helpers, and controllers to load.
    config.api_only = false

    # PaperTrail expects this; otherwise it complains during has_paper_trail.
    config.active_record.cache_versioning = false
  end
end

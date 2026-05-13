require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Cache classes in test — without this, models get reloaded between tests
  # and class macros like `has_paper_trail` get called multiple times, which
  # PaperTrail rejects.
  config.cache_classes = true
  config.eager_load = false
  config.public_file_server.enabled = true
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.action_dispatch.show_exceptions = :rescuable
  config.action_controller.allow_forgery_protection = false
  config.active_support.deprecation = :stderr
  config.action_mailer.delivery_method = :test
  config.action_mailer.default_url_options = { host: "example.com" }
  config.secret_key_base = "dummy-app-test-secret-key-base-not-used-in-production"
  config.active_storage.service = :test
end

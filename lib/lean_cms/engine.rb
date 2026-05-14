module LeanCms
  class Engine < ::Rails::Engine
    # Note: isolate_namespace is intentionally omitted so that all lean_cms_* route
    # helpers remain accessible in both the engine and host app without renaming views.

    # Override Rails' default engine_name derivation ("lean_cms_engine") so that
    # tailwindcss-rails' built-in engine discovery
    # (Tailwindcss::Engines.bundle, run before every tailwindcss:build) finds
    # our Tailwind sources at app/assets/tailwind/lean_cms/engine.css.
    engine_name "lean_cms"

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.factory_bot dir: "spec/factories"
    end

    # Add gem's JS to Propshaft's load path so Stimulus controllers can be served.
    # CSS (app/assets/lean_cms/) is discovered automatically via app/assets registration.
    # Guarded — hosts without Propshaft (e.g. our test dummy app) don't expose
    # config.assets at all.
    initializer "lean_cms.assets" do |app|
      app.config.assets.paths << root.join("app/javascript") if app.config.respond_to?(:assets)
    end

    # Register the gem's Stimulus controllers with the host app's importmap
    initializer "lean_cms.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb")
      end
    end

    # Make the gem's migrations available to the host app
    initializer "lean_cms.migrations" do |app|
      unless app.root.to_s == root.to_s
        config.paths["db/migrate"].expanded.each do |path|
          app.config.paths["db/migrate"] << path
        end
      end
    end

    # NOTE: We deliberately do NOT generate app/assets/builds/tailwind/lean_cms.css
    # ourselves. That's tailwindcss-rails' job: Tailwindcss::Engines.bundle (run as
    # the `tailwindcss:engines` task, which is a prereq of every `tailwindcss:build`
    # and `tailwindcss:watch`) walks Rails::Engine.subclasses, finds ours by
    # engine_name "lean_cms" (set above), and writes the bundle file containing
    # @import "<gem>/app/assets/tailwind/lean_cms/engine.css". Hosts then pull
    # this in from their own app/assets/tailwind/application.css — see the
    # install generator's `wire_tailwind` step.

    # Ensure host app always has a resolvable edit-controls stylesheet path.
    # Place it under app/assets/stylesheets so stylesheet logical path resolution
    # matches `stylesheet_link_tag "lean_cms/cms_edit_controls"`.
    initializer "lean_cms.edit_controls_css" do |app|
      next if app.root.to_s == root.to_s

      host_css = app.root.join("app/assets/stylesheets/lean_cms/cms_edit_controls.css")
      next if host_css.exist?

      require "fileutils"
      source_css = root.join("app/assets/lean_cms/cms_edit_controls.css")
      next unless source_css.exist?

      FileUtils.mkdir_p(host_css.dirname)
      File.write(host_css, source_css.read)
    end

    # Action Text ships a CSS file via `bin/rails action_text:install`, but
    # the gem's admin layout references it via `stylesheet_link_tag "actiontext"`
    # before that step would normally run. Drop a default copy into the host's
    # app/assets/stylesheets/ so a fresh install boots without a
    # Propshaft::MissingAssetError. Hosts can edit / replace the file freely;
    # we only write it once.
    initializer "lean_cms.actiontext_css" do |app|
      next if app.root.to_s == root.to_s

      host_css = app.root.join("app/assets/stylesheets/actiontext.css")
      next if host_css.exist?

      require "fileutils"
      source_css = root.join("app/assets/lean_cms/actiontext.css")
      next unless source_css.exist?

      FileUtils.mkdir_p(host_css.dirname)
      File.write(host_css, source_css.read)
    end

    # Load rake tasks
    rake_tasks do
      load LeanCms::Engine.root.join("lib/tasks/lean_cms.rake")
    end
  end
end

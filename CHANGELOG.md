# Changelog

All notable changes to Lean CMS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.8] — 2026-05-14

Small ergonomic follow-up to v0.2.7.

### Added
- **`cms_admin_bar` helper.** Wrapper around `render "lean_cms/shared/admin_bar"` so hosts don't have to remember the partial path. Available everywhere `LeanCms::PageContentHelper` is included.
- **Install generator output now documents the admin bar wiring.** New step 5 in the post-install instructions shows the exact `<body>` snippet hosts should paste into their public layout to surface the bar.

## [0.2.7] — 2026-05-14

Polish pass after putting the demo live at `demo.leancms.dev`. One bug fix, two ergonomic additions hosts can lean on instead of rebuilding themselves.

### Fixed
- **`LeanCms::PageContent.find_or_initialize_content` actually finds existing records now.** The lookup used `where(page: page, section: section, key: key).first`, but `where(page: ...)` resolves to the `belongs_to :page` association — emitting `WHERE page_id = NULL` and missing every existing record. Re-running `lean_cms:load_structure` (e.g. to pick up new YAML fields) was crashing on the SQLite unique index for every row. Now uses an explicit string-column comparison via `where("page = ? AND section = ? AND key = ?", …)`. Same shape of fix as the validation patches in v0.2.5.

### Added
- **`lean_cms/shared/_admin_bar` partial.** The fixed-top admin strip with the Inline Editing toggle, Help, Admin Dashboard, and Sign Out — previously every Lean CMS host had to copy/paste ~40 lines of ERB into their own public layout. Now hosts just `<%= render "lean_cms/shared/admin_bar" %>` from their layout and get the whole widget. The Admin Dashboard button reads its color from `LeanCms.primary_color`. Push the body's top padding down ~40px (e.g. Tailwind `pt-10`) when `current_user&.has_any_cms_permission?` is true so it doesn't overlap your header.
- **`LeanCms.docs_url` configuration option** (default `https://leancms.dev/docs/`). Drives the new Help icon in the admin bar and the admin-side `_header.html.erb`. Override in `config/initializers/lean_cms.rb` to point at internal docs instead.

## [0.2.6] — 2026-05-14

Two more demo-bootstrap fixes on top of v0.2.5 — `cards_section` was crashing with a `String#updated_at` error, and `bullets_section` was rendering silently empty even when bullet data existed.

### Fixed
- **`LeanCms::BaseComponent#cache_key` handles the String-slug `page` form.** The cache key called `page&.updated_at&.to_i` assuming `page` was always a `LeanCms::Page` record. In the standard helper-driven usage `cards_section("offerings")`, `page` is the slug String (`"trips"`) and `String#updated_at` blew up. Now branches: uses `page.updated_at` when it's a Page record, falls back to `LeanCms::PageContent.where(page: slug).maximum(:updated_at)` when it's a slug — preserves `touch: true` invalidation through the legacy path.
- **`LeanCms::BulletsSectionComponent` template rewritten.** The previous template split a `content_tag :div do %>` block across two `if can_edit_cms?` guards (open in one, close in another) plus an `<% return %>` inside the cache block. The result rendered as completely empty markup whenever bullets data was present — every bullets section on the public site showed only its heading with a large blank gap below. New template captures the `<ul>` once and wraps it in the edit-controls div only when an editor's signed in. Same behavior for editors, fixes the blank-render bug for public visitors.

## [0.2.5] — 2026-05-14

Two more bugs surfaced bootstrapping the demo site on top of v0.2.4. Both are pre-existing, both block a fresh install from completing `lean_cms:load_structure`.

### Fixed
- **`lean_cms:load_structure` no longer fails with "Page can't be blank" after the v0.2.4 fix.** With the slug now correctly written to the string column via `record[:page] = page`, validation still failed because `validates :page, presence: true` was checking the `belongs_to :page` association (which is `optional: true` and has a nil `page_id` on fresh installs). Replaced with `validate :page_slug_present` reading `read_attribute(:page)` so presence is enforced on the slug column. Added a `page_slug` reader as the public accessor for the slug, alongside the association.
- **Gem now ships the PaperTrail `versions` table migration.** Four gem models (`PageContent`, `Setting`, `Post`, `FormSubmission`) call `has_paper_trail`, but the install never created the underlying table. The first write on a fresh install crashed with `Could not find table 'versions'`. Added `db/migrate/20260514000001_create_paper_trail_versions.rb`; uses `create_table :versions, if_not_exists: true` plus a guarded `add_index`, so existing installs that ran `paper_trail:install` separately are unaffected.
- **Gem now ships the Action Text + Active Storage migrations.** `LeanCms::PageContent` calls `has_rich_text :rich_content`, `has_one_attached :image_file`, and `has_many_attached :card_images`; `LeanCms::Setting` calls `has_one_attached :file`. Without these tables, `lean_cms:load_structure` fails the moment it hits the first `rich_text` field. Added `db/migrate/20260514000002_create_action_text_tables.rb` and `db/migrate/20260514000003_create_active_storage_tables.rb`, both fully idempotent — hosts that ran `action_text:install` / `active_storage:install` separately get no-ops.
- **`(page, section, key)` uniqueness now scopes on the slug column, not the association FK.** The built-in `validates :key, uniqueness: { scope: [:page, :section] }` resolved `:page` to `page_id` (always NULL on fresh installs until the slug → `LeanCms::Page` normalization completes), so the scope collapsed to just `:section`. Records with the same section + key on different pages (e.g. `home/hero/heading` and `trips/hero/heading`) all blocked each other with "Key has already been taken". Replaced with a custom `validate :key_unique_within_page_section` that scopes on the slug via `read_attribute(:page)`.

## [0.2.4] — 2026-05-14

Surfaced while bootstrapping a fresh demo site from `lean_cms_structure.yml`.

### Fixed
- **`lean_cms:load_structure` no longer crashes with `ActiveRecord::AssociationTypeMismatch: LeanCms::Page expected, got "home"`.** `LeanCms::PageContent` has both a string column `page` (the slug) and a `belongs_to :page, class_name: 'LeanCms::Page'` association (FK on `page_id`). The association shadows the column for mass assignment, so `find_or_initialize_by(page: page_key, …)` was trying to coerce the slug string into a `LeanCms::Page` instance. Introduced `LeanCms::PageContent.find_or_initialize_content(page:, section:, key:)` which bypasses the association setter and writes the slug directly to the string column; the three call sites in the rake task (regular fields, cards, bullets) now route through it. Existing installs continue to work — the helper is purely additive.

## [0.2.3] — 2026-05-14

Doc-accuracy pass surfaced a couple of small gaps in the gem itself; rolled into this release.

### Added
- **`lean_cms:export_structure` rake task.** Dumps current `LeanCms::PageContent` records back into a YAML file shaped like `lean_cms_structure.yml`, with each field's current value emitted as its `default`. Useful for bootstrapping a second environment from a live database, or for documenting an existing install. Writes to `config/lean_cms_structure_export.yml` by default; override with `OUTPUT=path/to/file.yml`. Image attachments are not included — re-attach via the CMS UI or by copying ActiveStorage blobs.
- **Install template now generates `posts_per_page` and `portfolio_enabled` config lines.** Both options have existed in `LeanCms::Configuration` since v0.1.0 but were missing from the generated initializer, so most installs didn't know they could be tuned.

## [0.2.2] — 2026-05-13

The v0.2.1 Tailwind fix was incomplete — it stopped the RoutingError but didn't actually plug the gem's CSS into Tailwind's compile pipeline, so utilities for gem views weren't being emitted. This release adopts `tailwindcss-rails`' native engine support instead.

### Fixed
- **Engine name aligned with our Tailwind directory.** Set `engine_name "lean_cms"` explicitly. Rails' default derivation for `LeanCms::Engine` was `lean_cms_engine`, so `Tailwindcss::Engines.bundle` (the built-in `tailwindcss-rails` engine walker) was looking for `app/assets/tailwind/lean_cms_engine/engine.css` — never matched our `app/assets/tailwind/lean_cms/engine.css`. Now `tailwindcss-rails` finds and bundles us natively. Safe to change because we don't use `isolate_namespace` (no route helper prefixing).
- **Removed our `lean_cms.tailwind_css` initializer entirely.** It was duplicating `Tailwindcss::Engines.bundle` (which `tailwindcss-rails 4.x` runs as a prereq of every `tailwindcss:build` and `tailwindcss:watch`) — except buggily. The v0.2.1 attempt to fix it by inlining engine.css contents broke the relative `@source` paths. Letting tailwindcss-rails do its own thing is correct.

### Added
- **Install generator now wires up Tailwind.** New `wire_tailwind` step appends `@import "../builds/tailwind/lean_cms.css";` to the host's `app/assets/tailwind/application.css` so Tailwind actually scans the gem's views during compile. If no Tailwind input file is found, prints the line the user needs to paste themselves.

## [0.2.1] — 2026-05-13

Polish pass on the install + demo flow surfaced by an end-to-end test drive of v0.2.0 on a fresh Rails 8 app. No public API changes.

### Fixed
- **Install generator runs cleanly on fresh apps.** `CreateLeanCmsTables` migration crashed with `Unknown key: :foreign_key` because `t.integer :page_id, foreign_key: { to_table: ... }` is invalid syntax (only `t.references` accepts `foreign_key:`). Removed; the FK was already added at the bottom of the migration via `add_foreign_key`.
- **Install generator `destination_root.join` crash.** `destination_root` returns a String, not a Pathname. Switched to `File.join`.
- **Migrations are now portable across host user-table names.** Removed inline `foreign_key: { to_table: :users }` from every `t.references` pointing at the host user table (`lean_cms_posts.author`, `lean_cms_posts.last_edited_by`, `lean_cms_page_contents.last_edited_by`, `lean_cms_sessions.user`, `lean_cms_magic_links.user`). SQLite revalidates *all* FKs in a schema when ALTER triggers a table rebuild — without the host's users table (or with a non-`users` name like Devise's `admins`), this blew up `db:migrate` partway through. Models keep `belongs_to ..., class_name: "User"` for app-level integrity.
- **Lean CMS no longer requires User-side `has_many` associations.** Was conflicting with Rails 8's built-in `bin/rails generate authentication` which already adds `has_many :sessions`. Gem now uses `LeanCms::Session.create!(user: ...)` / `LeanCms::Session.where(user:).destroy_all` / `LeanCms::MagicLink.where(user:).for_purpose(...)` directly. Host User stays clean.
- **`lib/lean_cms.rb` now requires its runtime deps eagerly** — `paper_trail`, `view_component`, `kaminari`, `pundit`, `noticed`, `image_processing`, `meta-tags`, `rack-attack`. Hosts that `bundle add lean_cms` were hitting `NameError: uninitialized constant Pundit` when following install instructions, because Bundler doesn't auto-require transitive gemspec deps.
- **`lean_cms:load_structure` rake task.** Replaced dead `User.cms_admin.first` (pre-0.2 enum scope) with `LeanCms.user_class.constantize.where(is_super_admin: true).first || .first`.
- **Demo generator crashes.** `directory "views/shared"` referenced a non-existent template directory. Demo's `PagesController` template inherited `LeanCms::Authentication`'s default-protect and locked out public visitors; added `allow_unauthenticated_access`. Demo contact view used non-existent `submit_contact_path` helper; switched to `contact_path`.
- **Tailwind engine.css 404 on fresh installs.** The `lean_cms.tailwind_css` initializer was writing `@import "/Users/.../lean-cms/app/assets/tailwind/lean_cms/engine.css"` into the host's `app/assets/builds/tailwind/lean_cms.css`. That absolute filesystem path is fine for the Tailwind CLI at compile-time but leaks to the browser as a real HTTP request → Rails `RoutingError`. Initializer now inlines the engine's CSS contents instead of `@import`-ing them, and is guarded with `defined?(Tailwindcss::Engine)` so non-Tailwind hosts don't get the file at all.
- **Engine initializers no longer scribble into themselves when host == engine.** The Tailwind and edit-controls CSS initializers now `next if app.root == root` (mirroring the migrations initializer), preventing artifacts during in-repo test runs from polluting the gem's working tree.

### Added
- **Minitest test suite** under `test/` with a self-contained dummy Rails 8 app (`test/dummy/`) and in-memory SQLite. Runs via `bundle exec rake test`; CI now invokes it on every push and PR. Initial coverage: engine boot + table names + configuration, `LeanCms::Setting` get/set/JSON/lock helpers, `LeanCms::MagicLink` invitation / password-reset / expiration / invalidation.
- **`check_user_model` pre-flight in install generator.** Aborts with a clear message if the host's user table doesn't exist or is missing `email_address` / `password_digest` columns. Points consumers at `bin/rails generate authentication` (Rails 8 built-in), Devise, or `rails generate model`. Re-runnable.
- **`--user=ClassName` flag on the install generator** for hosts whose auth model isn't `User` (e.g. Devise's `Admin`). Drives both the pre-flight check (looks for the `admins` table) and the value written to `LeanCms.user_class` in the generated initializer.
- **`add_missing_user_columns` step in the install generator.** Diffs the host's user table against the nine Lean CMS-required columns (`name`, `active`, `must_change_password`, `last_login_at`, plus the five permission flags) and generates `db/migrate/add_lean_cms_columns_to_<table>.rb` with only the missing columns. The migration runs as part of the same install — clean install ends with a fully provisioned user table, zero schema hand-editing.
- **Rails 8 auth conflict detection.** If the host's `ApplicationController` includes `Authentication` (the concern Rails 8's `bin/rails generate authentication` ships), the install generator prints a prominent warning explaining the collision (both concerns define `before_action :require_authentication`; last-included wins; without cleanup `/lean-cms` redirects to `/session/new`). Lists the exact line to remove, files to delete, and routes to drop.
- **Self-contained auth-page styling.** Login, password reset, password setup pages now ship complete inline CSS keyed off `LeanCms.primary_color` / `secondary_color`. No Tailwind required for the auth flow — drops cleanly into any Rails 8 app with zero CSS framework setup. (Admin / post-login layout is still Tailwind-dependent — separate decision.)

### Changed
- **Pundit is now a gem-internal concern.** `LeanCms::ApplicationController` includes `Pundit::Authorization` itself. Hosts only need `include Pundit::Authorization` in their own AC if they want `authorize` / `policy_scope` available in their own non-CMS controllers — no longer a Lean CMS install step.
- Install generator's "Wire up your User model" instructions are shorter (no `has_many :sessions` line) and gain a note explaining that the gem uses `LeanCms::Session` directly to stay compatible with Rails 8 auth.

## [0.2.0] — 2026-05-13

### Added
- **Sloth mascot assets** under `app/assets/images/lean_cms/` — favicons (16/32/64), full logo, and 404/500 error illustrations. The gem's admin layouts (`lean_cms/application` and `lean_cms/auth`) now wire in the sloth favicon by default.
- `LeanCms::Setting.site_favicon_url` — returns the ActiveStorage URL of an uploaded favicon override, or `nil` if none is set. Host apps use this with a fallback to the gem's sloth PNGs for the public site's `<link rel="icon">`.
- `LeanCms::Setting.update_site_favicon!(io)` and `remove_site_favicon!` — programmatic helpers for the favicon attachment.
- Favicon upload UI in the Settings page (`/lean-cms/settings`) — admins can upload a PNG/ICO/SVG to override the default sloth on the public site, or remove it to fall back to the default.
- `has_one_attached :file` on `LeanCms::Setting` — supports per-setting file attachments (currently used only for `site_favicon`).

### Fixed
- `LeanCms::Setting.set` now references `LeanCms::Current.user` (was top-level `Current.user`, which would raise `NameError` after the auth-into-gem migration if any setting was saved from a controller).

### Added (continued)
- **Authentication owned by the gem.** Login, password reset, and magic-link password setup now live under `/lean-cms/login`, `/lean-cms/reset-password`, and `/lean-cms/setup-password/:token`. New gem-owned pieces:
  - `LeanCms::Authentication` controller concern — host's `ApplicationController` includes this to expose `current_user`, `authenticated?`, `start_new_session_for`, and `terminate_session`.
  - `LeanCms::Current` (replaces host `Current`) — `ActiveSupport::CurrentAttributes` with `session` and delegated `user`.
  - `LeanCms::Session` (table `lean_cms_sessions`) and `LeanCms::MagicLink` (table `lean_cms_magic_links`).
  - `LeanCms::SessionsController`, `PasswordsController`, `PasswordSetupController` with branded views rendered via the new `lean_cms/auth` layout.
  - `LeanCms::PasswordsMailer` (`reset`) and `LeanCms::UsersMailer` (`invitation`, `reactivation`, `admin_triggered_password_reset`).
  - Migration `CreateLeanCmsAuthTables` — idempotent (skips if tables already exist).
- `LeanCms.mailer_from` config — `From:` address for gem-sent emails (default: `noreply@example.com`).
- `lean_cms:optimize_images` rake task — reads originals from `app/assets/images/source/` and emits resized WebP + same-format fallback variants (default widths: 640/1280/1920) into `app/assets/images/`. Overridable via `WIDTHS`, `WEBP_QUALITY`, `JPEG_QUALITY` env vars. Idempotent (skips outputs newer than source). Powered by libvips via `image_processing`.
- `lean_cms_picture_tag(name, alt:, widths:, format:, sizes:, **img_options)` helper — renders a `<picture>` with a WebP `<source>` and a JPG/PNG fallback `<img>`, both with proper `srcset` for the configured widths. Defaults to lazy loading and async decoding. Use for static layout images optimized via `lean_cms:optimize_images`.

### Changed
- **BREAKING:** `LeanCms::Authorization` references `LeanCms::Current.user` (was `Current.user`). Hosts that previously relied on a top-level `Current` constant must either include the gem's auth (and remove their own `Current`) or alias `Current = LeanCms::Current`.
- **BREAKING:** auth URL helpers are namespaced: `lean_cms_new_session_path` (was `new_session_path`), `lean_cms_new_password_path`, `lean_cms_password_setup_path`, etc.

### Host migration notes
Hosts moving from in-app auth to gem auth should:
1. `bundle update lean_cms`, then `bin/rails db:migrate` to create `lean_cms_sessions` and `lean_cms_magic_links`.
2. Add `include LeanCms::Authentication` to `ApplicationController` (replacing any local `Authentication` concern).
3. Update User: `has_many :sessions, class_name: "LeanCms::Session", dependent: :destroy` and the same for `:magic_links`.
4. Delete local `SessionsController`, `PasswordsController`, `PasswordSetupController`, `Session`, `Current`, `MagicLink`, `PasswordsMailer`, `UsersMailer`, related views, and remove their routes.
5. Update any references to the unprefixed URL helpers to the `lean_cms_*` namespaced versions.
6. Optionally drop the old `sessions` and `magic_links` tables in a follow-up migration.
- `app/assets/tailwind/lean_cms/engine.css` — hooks into `tailwindcss-rails` v4 engine support so the gem's views and Stimulus controllers are scanned when compiling Tailwind CSS in the host app, fixing missing utility classes in production
- Content Sync card in Settings page showing live lock status with lock/unlock buttons and reason field
- Lock status banner in the CMS admin layout — displayed prominently across all pages when content is locked, with an inline Unlock button

### Fixed
- Register `app/javascript` with Propshaft's asset load path so Stimulus controllers are served correctly in production
- Content lock enforcement now also covers `update_field` and `undo_field` inline editing actions (previously only `update` was blocked)

## [0.1.0] - 2026-02-21

### Added
- Initial gem extraction from the CAS application
- Rails Engine with `isolate_namespace LeanCms`
- **9 content types**: `text`, `rich_text`, `image`, `boolean`, `url`, `color`, `dropdown`, `cards`, `bullets`
- In-context editing with hover-activated section overlays (`cms_editable_section`)
- Inline field editing with undo (`editable_content`)
- `LeanCms::CardsSectionComponent` — renders card grids with drag-to-reorder editor
- `LeanCms::BulletsSectionComponent` — renders bullet lists with inline editor
- `LeanCms::EditableContentComponent` — wraps fields with inline edit controls
- `LeanCms::SectionComponent` — section wrapper with caching and edit overlay
- Helper API: `page_content`, `page_content_html`, `page_content_image_url`, `page_content?`, `page_section`, `page_structure`, `page_cards`, `page_bullets`
- `cms_editable_section` and `cms_settings_section` helpers
- `cards_section` and `bullets_section` component helpers
- CMS admin: dashboard, page contents editor, posts (blog + portfolio), settings, users, form submissions, notifications, activity log
- `LeanCms::Setting` — key-value store with caching; convenience methods for site phone, email, address, business hours
- Content locking for safe database sync workflow
- `lean_cms:sync` rake task suite — pull, push, stage, start, finish, lock, unlock
- `rails generate lean_cms:install_kamal_hooks` — installs pre/post deploy hooks
- Stimulus controllers: `cms-sticky-overlay`, `inline-edit`, `inline-edit-toggle`, `cards-editor`, `settings-inline-edit-sync`, `settings-override`
- `cms_edit_controls.css` — styles for in-context editing overlays
- Pundit policies for `PageContent`, `Post`, `Setting`
- Role-based authorization via `LeanCms::Authorization` concern
- PaperTrail integration on `PageContent`, `Post`, `Setting`
- `lean_cms:load_structure` rake task — seeds content from `config/lean_cms_structure.yml`
- `lean_cms:stats` rake task — prints content field counts by page
- `LeanCms::SyncHelper` — SQLite database sync between local and production

[Unreleased]: https://github.com/Ovrland-Services/lean-cms/compare/v0.2.8...HEAD
[0.2.8]: https://github.com/Ovrland-Services/lean-cms/compare/v0.2.7...v0.2.8
[0.2.7]: https://github.com/Ovrland-Services/lean-cms/compare/v0.2.6...v0.2.7
[0.2.6]: https://github.com/Ovrland-Services/lean-cms/compare/v0.2.5...v0.2.6
[0.2.5]: https://github.com/Ovrland-Services/lean-cms/compare/v0.2.4...v0.2.5
[0.2.4]: https://github.com/Ovrland-Services/lean-cms/compare/v0.2.3...v0.2.4
[0.2.3]: https://github.com/Ovrland-Services/lean-cms/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/Ovrland-Services/lean-cms/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/Ovrland-Services/lean-cms/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/Ovrland-Services/lean-cms/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Ovrland-Services/lean-cms/releases/tag/v0.1.0

# Changelog

All notable changes to LeanCMS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/Ovrland-Services/lean-cms/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/Ovrland-Services/lean-cms/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Ovrland-Services/lean-cms/releases/tag/v0.1.0

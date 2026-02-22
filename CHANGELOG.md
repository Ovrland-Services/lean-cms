# Changelog

All notable changes to LeanCMS will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/OvrlandServices/lean-cms/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/OvrlandServices/lean-cms/releases/tag/v0.1.0

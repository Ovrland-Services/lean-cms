<p align="center">
  <img src="https://raw.githubusercontent.com/Ovrland-Services/lean-cms/main/app/assets/images/lean_cms/sloth-logo.png" alt="Lean CMS sloth mascot — a sloth reclining on a beanbag chair with sunglasses and a Ruby-stickered laptop" width="240">
</p>

<h1 align="center">Lean CMS</h1>

<p align="center">
  A lightweight Rails CMS with in-context editing for marketing sites.
  <br>
  <a href="https://leancms.dev"><strong>leancms.dev</strong></a>
</p>

---

Lean CMS is a Rails Engine that adds in-context content editing, page content
management, blog & portfolio, settings, role-based authentication, and
notifications to any Rails 8 application. It's designed for marketing sites:
server-rendered, no separate CMS service to host, and one rake task to
seed your whole site structure from YAML.

## Why Lean CMS

- **In-context editing** — content editors hover over any page section to
  reveal an Edit overlay; no separate "admin" interface for day-to-day edits.
- **You own your design** — the gem never touches your layouts or styles;
  helpers pull content into your own ERB templates.
- **YAML-defined structure** — every page, section, and field is declared in
  `config/lean_cms_structure.yml` and seeded with one rake task.
- **Built-in auth** — login, password reset, and magic-link invitations all
  shipped by the gem and namespaced under `/lean-cms`.
- **9 content types** — `text`, `rich_text`, `image`, `boolean`, `url`,
  `color`, `dropdown`, `cards`, `bullets`.
- **Version history** — every content edit tracked via PaperTrail; one-click
  undo.

## Installation

```ruby
# Gemfile
gem "lean_cms"
```

```bash
bundle install
rails generate lean_cms:install
rails db:migrate
```

Then in `app/controllers/application_controller.rb`:

```ruby
include LeanCms::Authentication
```

And in `app/helpers/application_helper.rb`:

```ruby
include LeanCms::PageContentHelper
```

See the [Getting Started guide](https://leancms.dev/docs/getting-started/installation/) for the full setup including User-model requirements and YAML structure.

> **Heads up — authentication.** Lean CMS ships its own auth (login at `/lean-cms/login`, sessions, magic-link invites). It coexists cleanly with Rails 8's built-in `bin/rails generate authentication` (the install generator detects + warns). **If you're already using Devise or another auth gem**, the gem currently still adds a second login screen — first-class host-auth integration is the v0.3 milestone. See [issue tracker](https://github.com/Ovrland-Services/lean-cms/issues) for status.

## A taste of the helper API

```erb
<%# A whole section, hover-editable for admins %>
<%= cms_editable_section(page: "home", section: "hero", display_title: "Hero") do %>
  <section class="hero">
    <h1><%= editable_content("hero", "heading") %></h1>
    <p><%= editable_content("hero", "subheading") %></p>

    <% bg = page_content_image_url(@page, "hero", "background") %>
    <% if bg %><%= image_tag bg, class: "absolute inset-0" %><% end %>
  </section>
<% end %>

<%# Responsive optimized <picture> for static layout images %>
<%= lean_cms_picture_tag "wire-panel",
      alt: "Wiring",
      widths: [640, 1280],
      sizes: "(min-width: 768px) 448px, 100vw",
      class: "rounded-2xl shadow-lg" %>
```

## Requirements

- Ruby ≥ 3.2
- Rails ≥ 8.0
- SQLite, PostgreSQL, or MySQL (SQLite is the happy path; see [Database support](https://leancms.dev/docs/deployment/database-support/) for the compatibility matrix)

## Roadmap

Lean CMS is `0.2.x` — pre-1.0, API may shift between minors. Public roadmap:

- **v0.2.x** _(current)_: feature-complete CMS surface, in-context editing, hourly-resettable demo. Ships its own auth.
- **v0.3**: host-auth adapter pattern — first-class integration with Devise / Rodauth / custom-auth hosts. Sibling [`lean-cms-devise-example`](https://github.com/Ovrland-Services/lean-cms) repo as the proving ground + public reference.
- **v0.4** _(idea stage)_: AI-powered `lean_cms-scraper` companion gem — `bin/rails generate lean_cms:scrape URL=...` writes a starter `lean_cms_structure.yml` from an existing live website.

## Demo

Live at [demo.leancms.dev](https://demo.leancms.dev) — sign in with `demo@leancms.dev` / `demo123` and edit anything. Content resets every hour at `:00 UTC`. Source: [`Ovrland-Services/lean-cms-demo`](https://github.com/Ovrland-Services/lean-cms-demo).

## License

MIT. See [LICENSE](LICENSE).

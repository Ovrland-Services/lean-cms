<p align="center">
  <img src="https://raw.githubusercontent.com/Ovrland-Services/lean-cms/main/app/assets/images/lean_cms/sloth-logo.png" alt="LeanCMS sloth mascot — a sloth reclining on a beanbag chair with sunglasses and a Ruby-stickered laptop" width="240">
</p>

<h1 align="center">LeanCMS</h1>

<p align="center">
  A lightweight Rails CMS with in-context editing for marketing sites.
  <br>
  <a href="https://leancms.dev"><strong>leancms.dev</strong></a>
</p>

---

LeanCMS is a Rails Engine that adds in-context content editing, page content
management, blog & portfolio, settings, role-based authentication, and
notifications to any Rails 8 application. It's designed for SQLite-based
marketing sites: server-rendered, single-binary deploys, no separate CMS to
host.

## Why LeanCMS

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
include Pundit::Authorization
```

And in `app/helpers/application_helper.rb`:

```ruby
include LeanCms::PageContentHelper
```

See the [Getting Started guide](https://leancms.dev/docs/getting-started/installation/) for the full setup including User-model requirements and YAML structure.

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
- SQLite3 (the gem assumes a SQLite host; see [SQLite Production](https://leancms.dev/docs/deployment/sqlite/))

## License

MIT. See [LICENSE](LICENSE).

require "lean_cms/version"
require "lean_cms/configuration"

# Runtime dependencies — explicitly required so consumers can use the
# constants (e.g. Pundit::Authorization in ApplicationController) without
# adding them to their host Gemfile. These are also declared in the
# gemspec.
require "paper_trail"
require "view_component"
require "kaminari"
require "pundit"
require "noticed"
require "image_processing/vips"
require "meta_tags"
require "rack/attack"

require "lean_cms/engine"
require "lean_cms/sync_helper"

module LeanCms
  # Table name prefix for all Lean CMS models
  def self.table_name_prefix
    "lean_cms_"
  end
end

require "lean_cms/version"
require "lean_cms/configuration"
require "lean_cms/engine"
require "lean_cms/sync_helper"

module LeanCms
  # Table name prefix for all Lean CMS models
  def self.table_name_prefix
    "lean_cms_"
  end
end

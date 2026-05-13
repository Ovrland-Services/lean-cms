require_relative "../test_helper"

class LeanCmsEngineTest < ActiveSupport::TestCase
  test "engine is defined and namespaced under LeanCms" do
    assert defined?(LeanCms::Engine)
    assert_operator LeanCms::Engine.instance, :kind_of?, Rails::Engine
  end

  test "VERSION is set" do
    assert_match(/\A\d+\.\d+\.\d+(-\w+)?\z/, LeanCms::VERSION)
  end

  test "gem models load and have the expected table names" do
    assert_equal "lean_cms_pages",            LeanCms::Page.table_name
    assert_equal "lean_cms_posts",            LeanCms::Post.table_name
    assert_equal "lean_cms_page_contents",    LeanCms::PageContent.table_name
    assert_equal "lean_cms_settings",         LeanCms::Setting.table_name
    assert_equal "lean_cms_sessions",         LeanCms::Session.table_name
    assert_equal "lean_cms_magic_links",      LeanCms::MagicLink.table_name
    assert_equal "lean_cms_form_submissions", LeanCms::FormSubmission.table_name
  end

  test "configuration defaults are sensible" do
    assert_equal "User",     LeanCms.user_class
    assert_equal "/lean-cms", LeanCms.admin_path
    assert_equal 10,         LeanCms.posts_per_page
  end
end

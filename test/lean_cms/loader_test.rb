require_relative "../test_helper"
require "tempfile"

class LeanCms::LoaderTest < ActiveSupport::TestCase
  setup do
    LeanCms::PageContent.delete_all
    @system_user = User.create!(
      email_address:       "loader-system@example.com",
      password:             "test-password",
      name:                 "Loader System",
      active:               true,
      must_change_password: false,
      is_super_admin:       true
    )
  end

  teardown do
    User.delete_all
  end

  test "raises StructureFileMissing when the YAML is absent" do
    loader = LeanCms::Loader.new(yaml_path: "/tmp/does-not-exist-#{Process.pid}.yml", system_user: @system_user)
    assert_raises(LeanCms::Loader::StructureFileMissing) { loader.load! }
  end

  test "raises NoUsersFound when no users exist and no system_user is passed" do
    User.delete_all

    with_yaml(<<~YAML) do |path|
      pages:
        home:
          display_title: "Home"
          page_order: 1
          sections:
            hero:
              fields:
                heading: { type: text, default: "Hello" }
    YAML
      loader = LeanCms::Loader.new(yaml_path: path)
      assert_raises(LeanCms::Loader::NoUsersFound) { loader.load! }
    end
  end

  test "loads a single text field, second run is idempotent (skipped count = 1)" do
    yaml = <<~YAML
      pages:
        home:
          display_title: "Home"
          page_order: 1
          sections:
            hero:
              display_title: "Hero"
              section_order: 1
              fields:
                heading:
                  type: text
                  label: "Hero Heading"
                  default: "Welcome"
    YAML

    with_yaml(yaml) do |path|
      first = LeanCms::Loader.new(yaml_path: path, system_user: @system_user).load!
      assert_equal 1, first.created
      assert_equal 0, first.updated
      assert_equal 0, first.skipped

      record = LeanCms::PageContent.where("page = ? AND section = ? AND key = ?", "home", "hero", "heading").first
      assert_equal "Welcome",      record.value
      assert_equal "Hero Heading", record.label

      second = LeanCms::Loader.new(yaml_path: path, system_user: @system_user).load!
      assert_equal 0, second.created
      assert_equal 0, second.updated
      assert_equal 1, second.skipped
    end
  end

  test "preserves stored value when re-running, even after editing default in YAML" do
    yaml_v1 = <<~YAML
      pages:
        home:
          page_order: 1
          sections:
            hero:
              section_order: 1
              fields:
                heading: { type: text, label: "Hero Heading", default: "First Value" }
    YAML

    yaml_v2 = <<~YAML
      pages:
        home:
          page_order: 1
          sections:
            hero:
              section_order: 1
              fields:
                heading: { type: text, label: "Hero Heading Renamed", default: "Second Value" }
    YAML

    with_yaml(yaml_v1) do |path|
      LeanCms::Loader.new(yaml_path: path, system_user: @system_user).load!
    end

    record = LeanCms::PageContent.where("page = ? AND section = ? AND key = ?", "home", "hero", "heading").first
    assert_equal "First Value", record.value

    with_yaml(yaml_v2) do |path|
      result = LeanCms::Loader.new(yaml_path: path, system_user: @system_user).load!
      assert_equal 0, result.created
      assert_equal 1, result.updated  # label changed
    end

    record.reload
    assert_equal "First Value",          record.value, "user-stored value must not be clobbered by changed YAML default"
    assert_equal "Hero Heading Renamed", record.label, "metadata (label) DOES get updated"
  end

  test "loads bullets section JSON into the content column" do
    yaml = <<~YAML
      pages:
        about:
          page_order: 1
          sections:
            principles:
              section_order: 1
              bullets:
                max_items: 5
                items:
                  - "Be kind"
                  - "Pack out trash"
    YAML

    with_yaml(yaml) do |path|
      result = LeanCms::Loader.new(yaml_path: path, system_user: @system_user).load!
      assert_equal 1, result.created
    end

    bullets = LeanCms::PageContent.where("page = ? AND section = ? AND key = ?", "about", "principles", "bullets").first
    assert_equal "bullets", bullets.content_type
    items = JSON.parse(bullets.content)
    assert_equal ["Be kind", "Pack out trash"], items
  end

  private

  def with_yaml(content)
    file = Tempfile.new(["lean_cms_structure", ".yml"])
    file.write(content)
    file.close
    yield file.path
  ensure
    file&.unlink
  end
end

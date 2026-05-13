require_relative "../test_helper"

class LeanCms::SettingTest < ActiveSupport::TestCase
  setup do
    LeanCms::Setting.delete_all
    Rails.cache.clear
  end

  test "get returns the default for an unknown key" do
    assert_equal "fallback", LeanCms::Setting.get("nonexistent_a", "fallback")
    assert_nil               LeanCms::Setting.get("nonexistent_b")
  end

  test "set persists and get returns the value" do
    LeanCms::Setting.set("site_phone", "(555) 123-4567")
    assert_equal "(555) 123-4567", LeanCms::Setting.get("site_phone")
  end

  test "site_phone / site_email convenience accessors round-trip" do
    LeanCms::Setting.set("site_phone", "555")
    LeanCms::Setting.set("site_email", "hi@example.com")
    assert_equal "555",            LeanCms::Setting.site_phone
    assert_equal "hi@example.com", LeanCms::Setting.site_email
  end

  test "enabled? reads booleans stored as strings" do
    LeanCms::Setting.set("show_blog", "true")
    LeanCms::Setting.set("show_portfolio", "false")
    assert     LeanCms::Setting.enabled?("show_blog")
    refute     LeanCms::Setting.enabled?("show_portfolio")
    refute     LeanCms::Setting.enabled?("never_set")
  end

  test "JSON storage helpers round-trip" do
    payload = { "hours" => [{ "days" => "Mon-Fri", "hours" => "9-5" }], "note" => "Closed holidays" }
    LeanCms::Setting.set_json("business_hours", payload)
    assert_equal payload, LeanCms::Setting.get_json("business_hours")
  end

  test "get_json returns the default on unparseable value" do
    LeanCms::Setting.set("broken_json", "this is not json")
    assert_equal({ "x" => 1 }, LeanCms::Setting.get_json("broken_json", { "x" => 1 }))
  end

  test "content lock methods toggle the lock state" do
    refute LeanCms::Setting.content_locked?
    LeanCms::Setting.lock_content!("Deploying new structure")
    assert LeanCms::Setting.content_locked?
    LeanCms::Setting.unlock_content!
    refute LeanCms::Setting.content_locked?
  end
end

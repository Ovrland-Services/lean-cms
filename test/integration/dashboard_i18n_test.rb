require_relative "../test_helper"
require "action_dispatch/testing/integration"

class DashboardI18nTest < ActionDispatch::IntegrationTest
  setup do
    LeanCms::Session.delete_all
    User.delete_all
    User.create!(
      email_address: "admin@example.com",
      password: "secret123",
      active: true,
      is_super_admin: true
    )
    post "/lean-cms/login", params: { email_address: "admin@example.com", password: "secret123" }
  end

  test "renders the dashboard in English by default" do
    get "/lean-cms"

    assert_response :success
    assert_includes response.body, "Dashboard"
    assert_includes response.body, "Published Posts"
    assert_includes response.body, "Quick Actions"
    refute_includes response.body, "translation missing"
  end

  test "renders the dashboard in pt-BR when the locale is pt-BR" do
    I18n.with_locale(:"pt-BR") { get "/lean-cms" }

    assert_response :success
    assert_includes response.body, "Painel"
    assert_includes response.body, "Posts publicados"
    assert_includes response.body, "Ações rápidas"
    refute_includes response.body, "translation missing"
  end
end

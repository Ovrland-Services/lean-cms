require_relative "../test_helper"
require "action_dispatch/testing/integration"

class AdminI18nTest < ActionDispatch::IntegrationTest
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

  test "renders the admin layout in pt-BR" do
    I18n.with_locale(:"pt-BR") { get "/lean-cms" }

    assert_includes response.body, '<html lang="pt-BR">'
    assert_includes response.body, "Envios de formulário"
    assert_includes response.body, "Registro de atividades"
    assert_includes response.body, "Novo post"
    assert_includes response.body, "Sair"
    refute_includes response.body, "translation missing"
  end

  test "renders the content lock banner in pt-BR" do
    LeanCms::Setting.lock_content!("Sincronizando")
    I18n.with_locale(:"pt-BR") { get "/lean-cms" }

    assert_includes response.body, "A edição de conteúdo está bloqueada."
    assert_match(/Bloqueada há menos de um minuto\./, response.body)
    assert_includes response.body, "Desbloquear"
  ensure
    LeanCms::Setting.unlock_content!
  end
end

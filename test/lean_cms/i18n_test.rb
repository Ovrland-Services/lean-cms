require_relative "../test_helper"

class LeanCmsI18nTest < ActiveSupport::TestCase
  include LeanCms::ApplicationHelper
  include ActionView::Helpers::DateHelper

  GEM_LOCALES = {
    en: LeanCms::Engine.root.join("config/locales/lean_cms.en.yml"),
    :"pt-BR" => LeanCms::Engine.root.join("config/locales/lean_cms.pt-BR.yml")
  }.freeze

  test "both gem locale files load without errors" do
    GEM_LOCALES.each do |locale, path|
      assert path.exist?, "missing locale file: #{path}"
      I18n.backend.load_translations(path.to_s)
      assert_includes I18n.available_locales, locale
    end
  end

  test "en and pt-BR have the same keys under lean_cms.*" do
    en_keys = flatten_keys(load_tree(:en, "lean_cms"))
    pt_keys = flatten_keys(load_tree(:"pt-BR", "lean_cms"))

    assert_equal en_keys.sort, pt_keys.sort,
      "missing in pt-BR: #{(en_keys - pt_keys).sort}\n" \
      "missing in en: #{(pt_keys - en_keys).sort}"
  end

  test "dashboard strings translate to pt-BR" do
    I18n.with_locale(:"pt-BR") do
      assert_equal "Painel", I18n.t("lean_cms.dashboard.index.title")
      assert_equal "Posts publicados", I18n.t("lean_cms.dashboard.index.stats.published_posts")
      assert_equal "Publicado", I18n.t("lean_cms.statuses.published")
    end
  end

  test "format_date/format_datetime follow the active locale" do
    datetime = Time.zone.local(2026, 9, 7, 15, 30)

    I18n.with_locale(:en) do
      assert_equal "September 07, 2026", format_date(datetime.to_date)
      assert_equal "September 07, 2026 at 03:30 PM", format_datetime(datetime)
    end

    I18n.with_locale(:"pt-BR") do
      assert_equal "7 de setembro de 2026", format_date(datetime.to_date)
      assert_equal "7 de setembro de 2026 às 15:30", format_datetime(datetime)
    end
  end

  test "time_ago_in_words works in pt-BR without rails-i18n" do
    I18n.with_locale(:"pt-BR") do
      assert_equal "3 dias", time_ago_in_words(3.days.ago)
      assert_equal "cerca de 1 hora", time_ago_in_words(1.hour.ago)
    end
  end

  private

  # Reads the locale's subtree straight from the YAML file so the parity check
  # doesn't depend on what's already loaded in the test process's backend.
  def load_tree(locale, namespace)
    tree = YAML.load_file(GEM_LOCALES[locale].to_s)
    tree.fetch(locale.to_s).fetch(namespace)
  end

  def flatten_keys(hash, prefix = nil)
    hash.flat_map do |key, value|
      full_key = [prefix, key].compact.join(".")
      value.is_a?(Hash) ? flatten_keys(value, full_key) : [full_key]
    end
  end
end

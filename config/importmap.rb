pin_all_from File.expand_path("../app/javascript/controllers", __dir__), under: "controllers"

# Action Text editor (Trix). The field-editor modal renders <trix-editor>
# for any rich_text field, which needs both `trix` and `@rails/actiontext`
# loaded. Pin them here so hosts get them automatically — host pins win
# on conflict if a host wants a different version.
pin "trix"
pin "@rails/actiontext", to: "actiontext.esm.js"

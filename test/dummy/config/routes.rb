Rails.application.routes.draw do
  # Pulled in via the gem's own config/routes.rb (auto-mounted by the engine).
  root to: proc { [200, {}, ["home"]] }
end

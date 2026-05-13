ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
require "active_support/test_case"
require "minitest/autorun"

# Establish an in-memory SQLite connection for tests. We bypass Rails'
# database.yml auto-loading (which tries to find config/database.yml
# relative to Rails.root and is finicky in dummy-app setups) and just
# wire ActiveRecord directly.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

# Run all migrations into the in-memory DB: dummy app's User table first,
# then the gem's tables.
ActiveRecord::Migration.verbose = false
[
  File.expand_path("dummy/db/migrate", __dir__),
  File.expand_path("../db/migrate",    __dir__)
].each do |dir|
  Dir.glob(File.join(dir, "*.rb")).sort.each do |path|
    require path
    classname = File.basename(path, ".rb").sub(/^\d+_/, "").camelize
    Object.const_get(classname).migrate(:up)
  end
end

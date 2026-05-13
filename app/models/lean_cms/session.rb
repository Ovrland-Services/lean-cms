module LeanCms
  class Session < ApplicationRecord
    self.table_name = "lean_cms_sessions"

    belongs_to :user, class_name: "User"
  end
end

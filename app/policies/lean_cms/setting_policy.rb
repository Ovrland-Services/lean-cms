# frozen_string_literal: true

module LeanCms
  class SettingPolicy < ApplicationPolicy
    def edit?
      user.can_access_settings?
    end

    def update?
      user.can_access_settings?
    end

    def update_override?
      user.can_access_settings?
    end
  end
end

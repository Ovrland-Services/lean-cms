# frozen_string_literal: true

module LeanCms
  class PostPolicy < ApplicationPolicy
    def index?
      user.can_edit_blog?
    end

    def show?
      user.can_edit_blog?
    end

    def create?
      user.can_edit_blog?
    end

    def update?
      return false unless user.can_edit_blog?
      # Super admins can edit any post, others can only edit their own
      user.is_super_admin? || record.author_id == user.id
    end

    def destroy?
      update?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        if user.can_edit_blog?
          scope.all
        else
          scope.none
        end
      end
    end
  end
end

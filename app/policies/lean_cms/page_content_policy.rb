# frozen_string_literal: true

module LeanCms
  class PageContentPolicy < ApplicationPolicy
    def index?
      user.can_edit_pages?
    end

    def show?
      user.can_edit_pages?
    end

    def update?
      user.can_edit_pages?
    end

    def edit?
      update?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        if user.can_edit_pages?
          scope.all
        else
          scope.none
        end
      end
    end
  end
end

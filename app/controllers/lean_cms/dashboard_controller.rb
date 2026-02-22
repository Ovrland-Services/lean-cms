module LeanCms
  class DashboardController < LeanCms::ApplicationController
    skip_before_action :check_content_lock

    def index
      @recent_posts = LeanCms::Post.recent.limit(5)
      @recent_submissions = LeanCms::FormSubmission.recent.limit(10)
      @unread_submissions_count = LeanCms::FormSubmission.unread.count
      @draft_posts_count = LeanCms::Post.draft.count
      @published_posts_count = LeanCms::Post.published.count
    end
  end
end

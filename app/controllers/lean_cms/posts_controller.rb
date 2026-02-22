module LeanCms
  class PostsController < LeanCms::ApplicationController
    before_action :require_blog_editing
    before_action :set_post, only: [:show, :edit, :update, :destroy]
    before_action :authorize_edit, only: [:edit, :update, :destroy]
    before_action :check_content_lock, only: [:destroy]

    def index
      @posts = LeanCms::Post.includes(:author, :last_edited_by)
                       .order(created_at: :desc)
      
      # Filter by content_type if provided
      if params[:content_type].present?
        case params[:content_type]
        when 'blog'
          @posts = @posts.blog_posts
        when 'portfolio'
          @posts = @posts.portfolio_items
        end
      end
    end

    def show
    end

    def new
      @post = LeanCms::Post.new
    end

    def create
      @post = LeanCms::Post.new(post_params)
      @post.author = current_user
      @post.last_edited_by = current_user

      if @post.save
        redirect_to lean_cms_posts_path, notice: 'Post created successfully.'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      @post.last_edited_by = current_user

      if @post.update(post_params)
        redirect_to lean_cms_posts_path, notice: 'Post updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @post.destroy
      redirect_to lean_cms_posts_path, notice: 'Post deleted successfully.'
    end

    private

    def set_post
      @post = LeanCms::Post.find(params[:id])
    end

    def authorize_edit
      unless can_edit?(@post)
        redirect_to lean_cms_posts_path, alert: 'You are not authorized to edit this post.'
      end
    end

    def post_params
      params.require(:lean_cms_post).permit(
        :title, :slug, :excerpt, :body, :status, :published_at, :content_type, :featured_image
      )
    end
  end
end

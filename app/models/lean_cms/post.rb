module LeanCms
  class Post < ApplicationRecord
    self.table_name = 'lean_cms_posts'

    has_paper_trail

    belongs_to :author, class_name: 'User'
    belongs_to :last_edited_by, class_name: 'User', optional: true

    has_rich_text :body
    has_one_attached :featured_image
    has_one :meta_tag, as: :taggable, class_name: 'LeanCms::MetaTag', dependent: :destroy

    enum :status, { draft: 0, published: 1 }
    enum :content_type, { blog: 0, portfolio: 1 }, prefix: :content

    validates :title, :slug, presence: true
    validates :slug, uniqueness: true
    validates :status, presence: true

    scope :published, -> { where(status: :published).where('published_at <= ?', Time.current) }
    scope :recent, -> { order(published_at: :desc) }
    scope :blog_posts, -> { content_blog }
    scope :portfolio_items, -> { content_portfolio }

    before_validation :generate_slug, if: -> { slug.blank? }
    before_validation :set_published_at, if: -> { status_changed? && published? && published_at.nil? }

    # Class method to find by slug
    def self.find_by_slug!(slug)
      find_by!(slug: slug)
    end

    # Check if post is published
    def published?
      status == 'published' && published_at.present? && published_at <= Time.current
    end

    # Get excerpt or truncated body
    def excerpt_or_body(length: 200)
      excerpt.presence || body.to_plain_text.truncate(length)
    end

    private

    def generate_slug
      return if title.blank?

      base_slug = title.parameterize
      slug_candidate = base_slug
      counter = 1

      while LeanCms::Post.where(slug: slug_candidate).where.not(id: id).exists?
        slug_candidate = "#{base_slug}-#{counter}"
        counter += 1
      end

      self.slug = slug_candidate
    end

    def set_published_at
      self.published_at = Time.current
    end
  end
end

module LeanCms
  class Page < ApplicationRecord
    self.table_name = 'lean_cms_pages'

    has_many :page_contents, class_name: 'LeanCms::PageContent', dependent: :destroy
    belongs_to :parent, class_name: 'Page', foreign_key: 'parent_slug', 
               primary_key: 'slug', optional: true
    has_many :children, class_name: 'Page', foreign_key: 'parent_slug', 
             primary_key: 'slug'
    
    validates :slug, presence: true, 
              uniqueness: { scope: :parent_slug }
    validates :title, presence: true
    
    scope :published, -> { where(published: true) }
    scope :root_pages, -> { where(parent_slug: nil) }
    scope :ordered, -> { order(:position, :title) }
    
    def full_path
      parent_slug ? "#{parent_slug}/#{slug}" : slug
    end
  end
end

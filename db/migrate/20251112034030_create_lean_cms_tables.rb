class CreateLeanCmsTables < ActiveRecord::Migration[8.1]
  def change
    # Pages (must come before page_contents for FK)
    create_table :lean_cms_pages, if_not_exists: true do |t|
      t.string  :slug,             null: false
      t.string  :parent_slug
      t.string  :title,            null: false
      t.string  :meta_title
      t.text    :meta_description
      t.boolean :published,        default: false, null: false
      t.integer :position,         default: 0
      t.timestamps

      t.index [:slug, :parent_slug], unique: true
    end

    # Posts
    create_table :lean_cms_posts, if_not_exists: true do |t|
      t.references :author,         null: false, foreign_key: { to_table: :users }
      t.references :last_edited_by,             foreign_key: { to_table: :users }
      t.string  :title,            null: false
      t.string  :slug,             null: false
      t.text    :excerpt
      t.integer :content_type,     default: 0, null: false
      t.integer :status,           default: 0, null: false
      t.datetime :published_at
      t.timestamps

      t.index :slug, unique: true
      t.index [:status, :published_at]
      t.index :content_type
    end

    # Page Contents
    create_table :lean_cms_page_contents, if_not_exists: true do |t|
      t.references :last_edited_by, null: false, foreign_key: { to_table: :users }
      t.integer :page_id
      # FK constraint added at the bottom of this migration after both tables
      # exist, so we can use add_foreign_key with an explicit column.
      t.string  :page,              null: false
      t.string  :section,           null: false
      t.string  :key,               null: false
      t.string  :label
      t.text    :content
      t.text    :value
      t.integer :content_type,      default: 0
      t.json    :options
      t.integer :position,          default: 0
      t.string  :display_title
      t.string  :page_display_title
      t.integer :page_order,        default: 0
      t.integer :section_order,     default: 0
      t.timestamps

      t.index [:page, :section, :key], unique: true, name: "index_page_contents_on_page_section_key"
      t.index [:page, :section],       name: "index_page_contents_on_page_and_section"
      t.index [:page_order, :section_order, :position]
      t.index :page_id
    end

    # Settings (key-value store)
    create_table :lean_cms_settings, if_not_exists: true do |t|
      t.string :key,   null: false
      t.text   :value
      t.timestamps

      t.index :key, unique: true
    end

    # Notification Settings
    create_table :lean_cms_notification_settings, if_not_exists: true do |t|
      t.string  :email_provider
      t.text    :sendgrid_api_key
      t.text    :mailgun_api_key
      t.string  :mailgun_domain
      t.text    :twilio_account_sid
      t.text    :twilio_auth_token
      t.string  :twilio_from_number
      t.text    :notification_emails
      t.text    :notification_phones
      t.boolean :email_enabled,   default: false
      t.boolean :sms_enabled,     default: false
      t.boolean :in_app_enabled,  default: true
      t.timestamps
    end

    # Meta Tags (polymorphic)
    create_table :lean_cms_meta_tags, if_not_exists: true do |t|
      t.references :taggable, polymorphic: true, null: false
      t.string :title
      t.text   :description
      t.string :og_image_url
      t.string :canonical_url
      t.json   :structured_data
      t.timestamps

      t.index [:taggable_type, :taggable_id]
    end

    # Form Submissions
    create_table :lean_cms_form_submissions, if_not_exists: true do |t|
      t.string  :form_type,       null: false
      t.string  :name
      t.string  :email
      t.string  :phone
      t.string  :company_name
      t.string  :city
      t.string  :state
      t.string  :zip
      t.text    :message
      t.json    :additional_data
      t.string  :ip_address
      t.string  :user_agent
      t.integer :status,          default: 0, null: false
      t.timestamps

      t.index :form_type
      t.index :status
      t.index :created_at
    end

    unless foreign_key_exists?(:lean_cms_page_contents, :lean_cms_pages, column: :page_id)
      add_foreign_key :lean_cms_page_contents, :lean_cms_pages, column: :page_id
    end
  end
end

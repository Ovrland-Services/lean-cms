class CreateTestUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :name
      t.boolean :active, default: true, null: false
      t.boolean :must_change_password, default: false, null: false
      t.datetime :last_login_at
      t.boolean :is_super_admin, default: false, null: false
      t.boolean :can_edit_pages, default: false, null: false
      t.boolean :can_edit_blog, default: false, null: false
      t.boolean :can_manage_users, default: false, null: false
      t.boolean :can_access_settings, default: false, null: false
      t.timestamps
      t.index :email_address, unique: true
    end
  end
end

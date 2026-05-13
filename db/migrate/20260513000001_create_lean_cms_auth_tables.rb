class CreateLeanCmsAuthTables < ActiveRecord::Migration[8.1]
  def change
    unless table_exists?(:lean_cms_sessions)
      create_table :lean_cms_sessions do |t|
        t.references :user, null: false, foreign_key: { to_table: :users }
        t.string :ip_address
        t.string :user_agent

        t.timestamps
      end
    end

    unless table_exists?(:lean_cms_magic_links)
      create_table :lean_cms_magic_links do |t|
        t.references :user, null: false, foreign_key: { to_table: :users }
        t.string :token, null: false
        t.string :purpose, null: false
        t.datetime :expires_at, null: false
        t.datetime :used_at
        t.string :created_by_ip
        t.string :used_from_ip

        t.timestamps
      end

      add_index :lean_cms_magic_links, :token, unique: true
      add_index :lean_cms_magic_links, [:user_id, :purpose]
      add_index :lean_cms_magic_links, :expires_at
    end
  end
end

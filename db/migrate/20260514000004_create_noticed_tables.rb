class CreateNoticedTables < ActiveRecord::Migration[7.1]
  # Mirrors `bin/rails noticed:install:migrations` output for noticed 3.x.
  # Idempotent — hosts that ran `noticed:install:migrations` separately get
  # no-ops on these tables.
  def change
    create_table :noticed_events, if_not_exists: true do |t|
      t.string :type
      t.belongs_to :record, polymorphic: true
      if t.respond_to?(:jsonb)
        t.jsonb :params
      else
        t.json :params
      end
      t.integer :notifications_count
      t.timestamps
    end

    create_table :noticed_notifications, if_not_exists: true do |t|
      t.string :type
      t.belongs_to :event, null: false
      t.belongs_to :recipient, polymorphic: true, null: false
      t.datetime :read_at
      t.datetime :seen_at
      t.timestamps
    end
  end
end

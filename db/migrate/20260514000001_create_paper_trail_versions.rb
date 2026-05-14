class CreatePaperTrailVersions < ActiveRecord::Migration[7.1]
  # Idempotent on existing installs that already ran `paper_trail:install`.
  def change
    create_table :versions, if_not_exists: true do |t|
      t.string   :item_type, null: false
      t.bigint   :item_id,   null: false
      t.string   :event,     null: false
      t.string   :whodunnit
      t.text     :object
      t.datetime :created_at
    end

    return if index_exists?(:versions, [:item_type, :item_id])
    add_index :versions, [:item_type, :item_id]
  end
end

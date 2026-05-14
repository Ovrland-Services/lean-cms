class CreateActiveStorageTables < ActiveRecord::Migration[7.1]
  # Mirrors `bin/rails active_storage:install` output. Idempotent.
  def change
    create_table :active_storage_blobs, if_not_exists: true do |t|
      t.string   :key,          null: false
      t.string   :filename,     null: false
      t.string   :content_type
      t.text     :metadata
      t.string   :service_name, null: false
      t.bigint   :byte_size,    null: false
      t.string   :checksum
      t.datetime :created_at,   null: false
    end
    add_index :active_storage_blobs, :key, unique: true, if_not_exists: true

    create_table :active_storage_attachments, if_not_exists: true do |t|
      t.string :name,     null: false
      t.references :record, null: false, polymorphic: true, index: false
      t.references :blob,   null: false
      t.datetime :created_at, null: false
    end

    unless index_exists?(:active_storage_attachments,
                         [:record_type, :record_id, :name, :blob_id],
                         name: "index_active_storage_attachments_uniqueness")
      add_index :active_storage_attachments,
                [:record_type, :record_id, :name, :blob_id],
                name: "index_active_storage_attachments_uniqueness",
                unique: true
    end

    create_table :active_storage_variant_records, if_not_exists: true do |t|
      t.belongs_to :blob, null: false, index: false
      t.string :variation_digest, null: false
    end

    return if index_exists?(:active_storage_variant_records,
                            [:blob_id, :variation_digest],
                            name: "index_active_storage_variant_records_uniqueness")
    add_index :active_storage_variant_records,
              [:blob_id, :variation_digest],
              name: "index_active_storage_variant_records_uniqueness",
              unique: true
  end
end

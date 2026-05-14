class CreateActionTextTables < ActiveRecord::Migration[7.1]
  # Mirrors `bin/rails action_text:install` output. Idempotent: hosts that
  # already ran action_text:install separately are unaffected.
  def change
    create_table :action_text_rich_texts, if_not_exists: true do |t|
      t.string :name, null: false
      t.text :body
      t.references :record, null: false, polymorphic: true, index: false
      t.timestamps
    end

    return if index_exists?(:action_text_rich_texts, [:record_type, :record_id, :name], name: "index_action_text_rich_texts_uniqueness")
    add_index :action_text_rich_texts,
              [:record_type, :record_id, :name],
              name: "index_action_text_rich_texts_uniqueness",
              unique: true
  end
end

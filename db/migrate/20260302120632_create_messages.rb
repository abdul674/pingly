class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :source, null: false, foreign_key: true
      t.string :external_id, null: false
      t.string :sender_name
      t.string :sender_avatar
      t.text :content
      t.boolean :mentioned, default: false
      t.string :deep_link
      t.jsonb :raw_data, default: {}
      t.datetime :received_at
      t.string :status, default: "unread", null: false
      t.datetime :snoozed_until
      t.timestamps
    end
    add_index :messages, [:source_id, :external_id], unique: true
    add_index :messages, :status
    add_index :messages, :received_at
    add_index :messages, :snoozed_until
  end
end

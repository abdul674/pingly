# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_02_120641) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "categories", force: :cascade do |t|
    t.string "color", default: "#6B7280"
    t.datetime "created_at", null: false
    t.integer "messages_count", default: 0, null: false
    t.string "name", null: false
    t.integer "position"
    t.datetime "updated_at", null: false
  end

  create_table "category_rules", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.string "match_type", default: "keyword", null: false
    t.string "pattern", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_category_rules_on_category_id"
  end

  create_table "message_categories", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.datetime "created_at", null: false
    t.bigint "message_id", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_message_categories_on_category_id"
    t.index ["message_id", "category_id"], name: "index_message_categories_on_message_id_and_category_id", unique: true
    t.index ["message_id"], name: "index_message_categories_on_message_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.string "deep_link"
    t.string "external_id", null: false
    t.boolean "mentioned", default: false
    t.jsonb "raw_data", default: {}
    t.datetime "received_at"
    t.string "sender_avatar"
    t.string "sender_name"
    t.datetime "snoozed_until"
    t.bigint "source_id", null: false
    t.string "status", default: "unread", null: false
    t.datetime "updated_at", null: false
    t.index ["received_at"], name: "index_messages_on_received_at"
    t.index ["snoozed_until"], name: "index_messages_on_snoozed_until"
    t.index ["source_id", "external_id"], name: "index_messages_on_source_id_and_external_id", unique: true
    t.index ["source_id"], name: "index_messages_on_source_id"
    t.index ["status"], name: "index_messages_on_status"
  end

  create_table "platform_connections", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "connection_method", default: "manual", null: false
    t.datetime "created_at", null: false
    t.text "credentials"
    t.string "external_team_id"
    t.string "platform", null: false
    t.datetime "updated_at", null: false
    t.string "workspace_name"
    t.index ["platform", "external_team_id"], name: "index_platform_connections_on_platform_and_external_team_id", unique: true
  end

  create_table "sources", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.integer "messages_count", default: 0, null: false
    t.jsonb "metadata", default: {}
    t.boolean "monitored", default: true, null: false
    t.string "name"
    t.bigint "parent_id"
    t.bigint "platform_connection_id", null: false
    t.string "source_type"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_sources_on_parent_id"
    t.index ["platform_connection_id", "external_id"], name: "index_sources_on_platform_connection_id_and_external_id", unique: true
    t.index ["platform_connection_id"], name: "index_sources_on_platform_connection_id"
  end

  add_foreign_key "category_rules", "categories"
  add_foreign_key "message_categories", "categories"
  add_foreign_key "message_categories", "messages"
  add_foreign_key "messages", "sources"
  add_foreign_key "sources", "platform_connections"
  add_foreign_key "sources", "sources", column: "parent_id"
end

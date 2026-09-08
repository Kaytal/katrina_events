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

ActiveRecord::Schema[8.1].define(version: 2026_09_08_215252) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "event_exceptions", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.datetime "ends_at"
    t.bigint "event_id", null: false
    t.date "original_date", null: false
    t.datetime "starts_at"
    t.datetime "updated_at", null: false
    t.index ["event_id", "original_date"], name: "index_event_exceptions_on_event_id_and_original_date", unique: true
    t.index ["event_id"], name: "index_event_exceptions_on_event_id"
    t.check_constraint "action::text = 'move'::text AND starts_at IS NOT NULL AND ends_at IS NOT NULL AND ends_at > starts_at OR action::text = 'skip'::text AND starts_at IS NULL AND ends_at IS NULL", name: "event_exceptions_move_has_times"
    t.check_constraint "action::text = ANY (ARRAY['skip'::character varying, 'move'::character varying]::text[])", name: "event_exceptions_action_valid"
  end

  create_table "event_types", force: :cascade do |t|
    t.string "color", default: "#6b3f7a", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_event_types_on_slug", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.boolean "all_day", default: false, null: false
    t.boolean "bookable", default: false, null: false
    t.integer "capacity"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "ends_at", null: false
    t.bigint "event_type_id", null: false
    t.string "price_note"
    t.string "recurrence_rule"
    t.datetime "recurrence_until"
    t.datetime "starts_at", null: false
    t.string "status", default: "scheduled", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "venue_id"
    t.index ["event_type_id"], name: "index_events_on_event_type_id"
    t.index ["starts_at"], name: "index_events_on_starts_at"
    t.index ["status"], name: "index_events_on_status"
    t.index ["venue_id"], name: "index_events_on_venue_id"
    t.check_constraint "capacity IS NULL OR capacity > 0", name: "events_capacity_positive"
    t.check_constraint "ends_at > starts_at", name: "events_end_after_start"
    t.check_constraint "status::text = ANY (ARRAY['scheduled'::character varying, 'cancelled'::character varying]::text[])", name: "events_status_valid"
  end

  create_table "jwt_denylist", force: :cascade do |t|
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.index ["exp"], name: "index_jwt_denylist_on_exp"
    t.index ["jti"], name: "index_jwt_denylist_on_jti", unique: true
  end

  create_table "pages", force: :cascade do |t|
    t.text "body", default: "", null: false
    t.datetime "created_at", null: false
    t.string "meta_description"
    t.datetime "published_at"
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_pages_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.string "role", default: "admin", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "venues", force: :cascade do |t|
    t.string "address"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["name"], name: "index_venues_on_name", unique: true
  end

  add_foreign_key "event_exceptions", "events"
  add_foreign_key "events", "event_types"
  add_foreign_key "events", "venues"
end

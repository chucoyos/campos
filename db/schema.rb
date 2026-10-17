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

ActiveRecord::Schema[8.1].define(version: 2026_10_16_200000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "cargo_items", force: :cascade do |t|
    t.bigint "cargo_manifest_id", null: false
    t.bigint "cargo_packaging_id", null: false
    t.string "description", null: false
    t.integer "quantity", default: 1, null: false
    t.decimal "weight_kg", precision: 12, scale: 3
    t.string "origin_identifier"
    t.string "qr_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cargo_manifest_id"], name: "index_cargo_items_on_cargo_manifest_id"
    t.index ["cargo_packaging_id"], name: "index_cargo_items_on_cargo_packaging_id"
    t.index ["qr_token"], name: "index_cargo_items_on_qr_token", unique: true, where: "(qr_token IS NOT NULL)"
    t.check_constraint "quantity > 0", name: "cargo_items_quantity_positive"
    t.check_constraint "weight_kg IS NULL OR weight_kg > 0::numeric", name: "cargo_items_weight_positive"
  end

  create_table "cargo_manifests", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "container_id"
    t.string "status", default: "draft", null: false
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_cargo_manifests_on_client_id"
    t.index ["container_id"], name: "index_cargo_manifests_on_container_id", unique: true, where: "(container_id IS NOT NULL)"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying::text, 'confirmed'::character varying::text])", name: "cargo_manifests_status_valid"
  end

  create_table "cargo_packagings", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.string "tracking_mode", null: false
    t.boolean "weight_required", default: false, null: false
    t.boolean "qr_allowed", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_cargo_packagings_on_code", unique: true
    t.check_constraint "tracking_mode::text = 'aggregate'::text OR weight_required = true", name: "cargo_packagings_individual_weight_required"
    t.check_constraint "tracking_mode::text = 'individual'::text OR weight_required = false AND qr_allowed = false", name: "cargo_packagings_aggregate_capabilities_valid"
    t.check_constraint "tracking_mode::text = ANY (ARRAY['individual'::character varying::text, 'aggregate'::character varying::text])", name: "cargo_packagings_tracking_mode_valid"
  end

  create_table "carriers", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_carriers_on_name"
  end

  create_table "clients", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_clients_on_name"
  end

  create_table "containers", force: :cascade do |t|
    t.string "number", null: false
    t.integer "size", null: false
    t.string "container_type", null: false
    t.string "status", null: false
    t.bigint "master_bl_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["master_bl_id"], name: "index_containers_on_master_bl_id"
    t.index ["number"], name: "index_containers_on_number"
    t.index ["status"], name: "index_containers_on_status"
  end

  create_table "master_bls", force: :cascade do |t|
    t.string "number", null: false
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_master_bls_on_client_id"
    t.index ["number"], name: "index_master_bls_on_number", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "client_id"
    t.bigint "carrier_id"
    t.index ["carrier_id"], name: "index_users_on_carrier_id"
    t.index ["client_id"], name: "index_users_on_client_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  create_table "yard_blocks", force: :cascade do |t|
    t.string "code", null: false
    t.integer "bays", null: false
    t.integer "rows", null: false
    t.integer "levels", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_yard_blocks_on_code", unique: true
    t.check_constraint "bays > 0 AND rows >= 1 AND rows <= 26 AND levels > 0", name: "yard_blocks_dimensions_positive"
  end

  create_table "yard_slots", force: :cascade do |t|
    t.bigint "yard_block_id", null: false
    t.integer "bay", null: false
    t.string "row", limit: 1, null: false
    t.integer "level", null: false
    t.string "code", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_yard_slots_on_code", unique: true
    t.index ["yard_block_id", "bay", "row", "level"], name: "index_yard_slots_on_position", unique: true
    t.index ["yard_block_id"], name: "index_yard_slots_on_yard_block_id"
    t.check_constraint "bay > 0 AND level > 0 AND \"row\"::text ~ '^[A-Z]$'::text", name: "yard_slots_position_valid"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cargo_items", "cargo_manifests"
  add_foreign_key "cargo_items", "cargo_packagings"
  add_foreign_key "cargo_manifests", "clients"
  add_foreign_key "cargo_manifests", "containers"
  add_foreign_key "containers", "master_bls"
  add_foreign_key "master_bls", "clients"
  add_foreign_key "users", "carriers"
  add_foreign_key "users", "clients"
  add_foreign_key "yard_slots", "yard_blocks"
end

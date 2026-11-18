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

ActiveRecord::Schema[8.1].define(version: 2026_11_18_195651) do
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

  create_table "cargo_dispatch_allocations", force: :cascade do |t|
    t.bigint "cargo_dispatch_trip_id", null: false
    t.bigint "cargo_dispatch_instruction_id", null: false
    t.bigint "cargo_item_id", null: false
    t.integer "reserved_quantity", null: false
    t.integer "reported_quantity", default: 0, null: false
    t.integer "loaded_quantity", default: 0, null: false
    t.string "status", default: "reserved", null: false
    t.bigint "warehouse_slot_id"
    t.string "slot_section", limit: 1
    t.bigint "confirmed_by_id"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "reported_by_id"
    t.datetime "reported_at"
    t.index ["cargo_dispatch_instruction_id"], name: "index_dispatch_allocations_on_instruction"
    t.index ["cargo_dispatch_trip_id", "cargo_dispatch_instruction_id", "cargo_item_id"], name: "index_dispatch_allocations_on_trip_instruction_item", unique: true
    t.index ["cargo_dispatch_trip_id"], name: "index_dispatch_allocations_on_trip"
    t.index ["cargo_item_id"], name: "index_cargo_dispatch_allocations_on_cargo_item_id"
    t.index ["confirmed_by_id"], name: "index_cargo_dispatch_allocations_on_confirmed_by_id"
    t.index ["reported_by_id"], name: "index_cargo_dispatch_allocations_on_reported_by_id"
    t.index ["warehouse_slot_id"], name: "index_cargo_dispatch_allocations_on_warehouse_slot_id"
    t.check_constraint "reserved_quantity > 0 AND reported_quantity >= 0 AND reported_quantity <= reserved_quantity AND loaded_quantity >= 0 AND loaded_quantity <= reported_quantity", name: "cargo_dispatch_allocations_quantities_valid"
    t.check_constraint "status::text = ANY (ARRAY['reserved'::character varying::text, 'confirmed'::character varying::text, 'released'::character varying::text])", name: "cargo_dispatch_allocations_status_valid"
    t.check_constraint "warehouse_slot_id IS NULL AND slot_section IS NULL OR warehouse_slot_id IS NOT NULL AND slot_section IS NOT NULL AND (slot_section::text = ANY (ARRAY['A'::character varying::text, 'B'::character varying::text, 'C'::character varying::text]))", name: "cargo_dispatch_allocations_location_valid"
  end

  create_table "cargo_dispatch_events", force: :cascade do |t|
    t.bigint "cargo_dispatch_trip_id", null: false
    t.bigint "user_id", null: false
    t.bigint "cargo_dispatch_pass_id"
    t.string "event", null: false
    t.text "details"
    t.datetime "created_at", null: false
    t.index ["cargo_dispatch_pass_id"], name: "index_dispatch_events_on_pass"
    t.index ["cargo_dispatch_trip_id"], name: "index_dispatch_events_on_trip"
    t.index ["user_id"], name: "index_cargo_dispatch_events_on_user_id"
  end

  create_table "cargo_dispatch_instruction_containers", force: :cascade do |t|
    t.bigint "cargo_dispatch_instruction_id", null: false
    t.bigint "container_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cargo_dispatch_instruction_id", "container_id"], name: "index_dispatch_instruction_containers_on_instruction_container", unique: true
    t.index ["container_id"], name: "index_cargo_dispatch_instruction_containers_on_container_id"
  end

  create_table "cargo_dispatch_instructions", force: :cascade do |t|
    t.bigint "cargo_dispatch_request_id", null: false
    t.bigint "container_id"
    t.bigint "cargo_packaging_id"
    t.string "criterion", null: false
    t.integer "quantity"
    t.decimal "weight_kg", precision: 12, scale: 3
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cargo_dispatch_request_id"], name: "index_dispatch_instructions_on_request"
    t.index ["cargo_packaging_id"], name: "index_cargo_dispatch_instructions_on_cargo_packaging_id"
    t.index ["container_id"], name: "index_cargo_dispatch_instructions_on_container_id"
    t.check_constraint "(criterion::text = ANY (ARRAY['all'::character varying::text, 'half'::character varying::text])) AND container_id IS NOT NULL AND cargo_packaging_id IS NULL AND quantity IS NULL AND weight_kg IS NULL OR criterion::text = 'quantity'::text AND cargo_packaging_id IS NOT NULL AND quantity IS NOT NULL AND quantity > 0 AND weight_kg IS NULL OR criterion::text = 'weight'::text AND quantity IS NULL AND weight_kg IS NOT NULL AND weight_kg > 0::numeric", name: "cargo_dispatch_instructions_details_valid"
    t.check_constraint "criterion::text = ANY (ARRAY['all'::character varying::text, 'half'::character varying::text, 'quantity'::character varying::text, 'weight'::character varying::text])", name: "cargo_dispatch_instructions_criterion_valid"
  end

  create_table "cargo_dispatch_passes", force: :cascade do |t|
    t.bigint "cargo_dispatch_trip_id", null: false
    t.bigint "requested_by_id", null: false
    t.string "token", null: false
    t.string "status", default: "active", null: false
    t.string "operator_name", null: false
    t.string "plate", null: false
    t.string "economic_number"
    t.string "unit_type", null: false
    t.datetime "issued_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "entered_at"
    t.datetime "exit_scanned_at"
    t.datetime "completed_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cargo_dispatch_trip_id"], name: "index_dispatch_passes_on_active_trip", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["cargo_dispatch_trip_id"], name: "index_dispatch_passes_on_trip"
    t.index ["requested_by_id"], name: "index_cargo_dispatch_passes_on_requested_by_id"
    t.index ["token"], name: "index_cargo_dispatch_passes_on_token", unique: true
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying::text, 'completed'::character varying::text, 'cancelled'::character varying::text, 'expired'::character varying::text])", name: "cargo_dispatch_passes_status_valid"
    t.check_constraint "unit_type::text = ANY (ARRAY['sencillo'::character varying::text, 'full'::character varying::text])", name: "cargo_dispatch_passes_unit_type_valid"
  end

  create_table "cargo_dispatch_requests", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "requested_by_id", null: false
    t.string "destination", null: false
    t.string "status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_cargo_dispatch_requests_on_client_id"
    t.index ["requested_by_id"], name: "index_cargo_dispatch_requests_on_requested_by_id"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'in_progress'::character varying::text, 'completed'::character varying::text, 'cancelled'::character varying::text])", name: "cargo_dispatch_requests_status_valid"
  end

  create_table "cargo_dispatch_trips", force: :cascade do |t|
    t.bigint "cargo_dispatch_request_id", null: false
    t.bigint "carrier_id"
    t.bigint "created_by_id", null: false
    t.string "origin_type", null: false
    t.string "status", default: "pending", null: false
    t.string "transport_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "transport_mode", default: "assigned", null: false
    t.boolean "exit_evidence_enabled", default: true, null: false
    t.index ["cargo_dispatch_request_id"], name: "index_dispatch_trips_on_request"
    t.index ["carrier_id"], name: "index_cargo_dispatch_trips_on_carrier_id"
    t.index ["created_by_id"], name: "index_cargo_dispatch_trips_on_created_by_id"
    t.check_constraint "origin_type::text = ANY (ARRAY['mbl'::character varying::text, 'general'::character varying::text])", name: "cargo_dispatch_trips_origin_valid"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying::text, 'prepared'::character varying::text, 'in_yard'::character varying::text, 'loaded'::character varying::text, 'completed'::character varying::text, 'cancelled'::character varying::text])", name: "cargo_dispatch_trips_status_valid"
    t.check_constraint "transport_mode::text = 'assigned'::text AND transport_name IS NULL OR transport_mode::text = 'customer'::text AND origin_type::text = 'general'::text AND carrier_id IS NULL", name: "cargo_dispatch_trips_transport_valid"
  end

  create_table "cargo_item_movements", force: :cascade do |t|
    t.bigint "cargo_item_id", null: false
    t.bigint "from_slot_id"
    t.string "from_section", limit: 1
    t.bigint "to_slot_id", null: false
    t.string "to_section", limit: 1, null: false
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.index ["cargo_item_id", "created_at"], name: "index_cargo_item_movements_on_cargo_item_id_and_created_at"
    t.index ["cargo_item_id"], name: "index_cargo_item_movements_on_cargo_item_id"
    t.index ["from_slot_id"], name: "index_cargo_item_movements_on_from_slot_id"
    t.index ["to_slot_id"], name: "index_cargo_item_movements_on_to_slot_id"
    t.index ["user_id"], name: "index_cargo_item_movements_on_user_id"
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
    t.bigint "warehouse_slot_id"
    t.string "slot_section", limit: 1
    t.string "status", default: "captured", null: false
    t.index ["cargo_manifest_id"], name: "index_cargo_items_on_cargo_manifest_id"
    t.index ["cargo_packaging_id"], name: "index_cargo_items_on_cargo_packaging_id"
    t.index ["qr_token"], name: "index_cargo_items_on_qr_token", unique: true, where: "(qr_token IS NOT NULL)"
    t.index ["warehouse_slot_id"], name: "index_cargo_items_on_warehouse_slot_id"
    t.check_constraint "(warehouse_slot_id IS NULL) = (slot_section IS NULL) AND (status::text = 'stored'::text) = (warehouse_slot_id IS NOT NULL)", name: "cargo_items_location_consistent"
    t.check_constraint "quantity > 0", name: "cargo_items_quantity_positive"
    t.check_constraint "slot_section::text = ANY (ARRAY['A'::character varying::text, 'B'::character varying::text, 'C'::character varying::text])", name: "cargo_items_slot_section_valid"
    t.check_constraint "status::text = ANY (ARRAY['captured'::character varying::text, 'stored'::character varying::text, 'dispatched'::character varying::text])", name: "cargo_items_status_valid"
    t.check_constraint "weight_kg IS NULL OR weight_kg > 0::numeric", name: "cargo_items_weight_positive"
  end

  create_table "cargo_manifest_events", force: :cascade do |t|
    t.bigint "cargo_manifest_id", null: false
    t.bigint "user_id"
    t.string "event", null: false
    t.string "from_status", null: false
    t.string "to_status", null: false
    t.datetime "created_at", null: false
    t.index ["cargo_manifest_id", "created_at"], name: "idx_on_cargo_manifest_id_created_at_1692a9d850"
    t.index ["cargo_manifest_id"], name: "index_cargo_manifest_events_on_cargo_manifest_id"
    t.index ["user_id"], name: "index_cargo_manifest_events_on_user_id"
    t.check_constraint "event::text = ANY (ARRAY['confirm'::character varying::text, 'reopen'::character varying::text])", name: "cargo_manifest_events_event_valid"
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
    t.string "container_color"
    t.index ["name"], name: "index_clients_on_name"
  end

  create_table "container_assignments", force: :cascade do |t|
    t.bigint "container_id", null: false
    t.bigint "carrier_id", null: false
    t.bigint "assigned_by_id"
    t.bigint "yard_area_id"
    t.bigint "yard_area_section_id"
    t.string "operation", null: false
    t.string "status", default: "pendiente", null: false
    t.integer "preferred_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_by_id"], name: "index_container_assignments_on_assigned_by_id"
    t.index ["carrier_id"], name: "index_container_assignments_on_carrier_id"
    t.index ["container_id", "operation"], name: "index_container_assignments_open_unique", unique: true, where: "((status)::text = 'pendiente'::text)"
    t.index ["container_id"], name: "index_container_assignments_on_container_id"
    t.index ["yard_area_id"], name: "index_container_assignments_on_yard_area_id"
    t.index ["yard_area_section_id"], name: "index_container_assignments_on_yard_area_section_id"
    t.check_constraint "operation::text = ANY (ARRAY['ingreso'::character varying::text, 'salida'::character varying::text])", name: "container_assignments_operation_valid"
    t.check_constraint "preferred_level IS NULL OR preferred_level > 0", name: "container_assignments_level_positive"
  end

  create_table "container_movements", force: :cascade do |t|
    t.bigint "container_id", null: false
    t.bigint "movement_pass_id"
    t.bigint "from_yard_slot_id"
    t.bigint "to_yard_slot_id"
    t.bigint "user_id"
    t.string "movement_type", null: false
    t.string "load_status"
    t.datetime "created_at", null: false
    t.index ["container_id", "created_at"], name: "index_container_movements_on_container_id_and_created_at"
    t.index ["container_id"], name: "index_container_movements_on_container_id"
    t.index ["from_yard_slot_id"], name: "index_container_movements_on_from_yard_slot_id"
    t.index ["movement_pass_id"], name: "index_container_movements_on_movement_pass_id", unique: true, where: "(movement_pass_id IS NOT NULL)"
    t.index ["to_yard_slot_id"], name: "index_container_movements_on_to_yard_slot_id"
    t.index ["user_id"], name: "index_container_movements_on_user_id"
    t.check_constraint "load_status IS NULL OR (load_status::text = ANY (ARRAY['lleno'::character varying::text, 'vacio'::character varying::text]))", name: "container_movements_load_status_valid"
    t.check_constraint "movement_type::text = 'ingreso'::text AND from_yard_slot_id IS NULL AND to_yard_slot_id IS NOT NULL OR movement_type::text = 'salida'::text AND from_yard_slot_id IS NOT NULL AND to_yard_slot_id IS NULL OR movement_type::text = 'traspaleo'::text AND from_yard_slot_id IS NULL AND to_yard_slot_id IS NULL OR movement_type::text = 'reacomodo'::text AND from_yard_slot_id IS NOT NULL AND to_yard_slot_id IS NOT NULL", name: "container_movements_slots_valid"
    t.check_constraint "movement_type::text = 'reacomodo'::text AND movement_pass_id IS NULL OR movement_type::text <> 'reacomodo'::text AND movement_pass_id IS NOT NULL", name: "container_movements_pass_valid"
    t.check_constraint "movement_type::text = ANY (ARRAY['ingreso'::character varying::text, 'salida'::character varying::text, 'traspaleo'::character varying::text, 'reacomodo'::character varying::text])", name: "container_movements_type_valid"
  end

  create_table "containers", force: :cascade do |t|
    t.string "number", null: false
    t.integer "size", null: false
    t.string "container_type", null: false
    t.string "status", null: false
    t.bigint "master_bl_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "client_id"
    t.bigint "current_yard_slot_id"
    t.datetime "closed_at"
    t.index ["client_id"], name: "index_containers_on_client_id"
    t.index ["current_yard_slot_id"], name: "index_containers_on_current_yard_slot_id", unique: true, where: "(current_yard_slot_id IS NOT NULL)"
    t.index ["master_bl_id"], name: "index_containers_on_master_bl_id"
    t.index ["number"], name: "index_containers_on_number_active", unique: true, where: "(closed_at IS NULL)"
    t.index ["status"], name: "index_containers_on_status"
  end

  create_table "deconsolidations", force: :cascade do |t|
    t.bigint "container_id", null: false
    t.bigint "created_by_id"
    t.string "status", default: "apertura", null: false
    t.datetime "started_at"
    t.datetime "emptied_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["container_id"], name: "index_deconsolidations_on_container_id", unique: true
    t.index ["created_by_id"], name: "index_deconsolidations_on_created_by_id"
    t.index ["status"], name: "index_deconsolidations_on_status"
    t.check_constraint "status::text = ANY (ARRAY['apertura'::character varying::text, 'desconsolidando'::character varying::text, 'vacio'::character varying::text, 'vaciado'::character varying::text])", name: "deconsolidations_status_valid"
  end

  create_table "master_bls", force: :cascade do |t|
    t.string "number", null: false
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_master_bls_on_client_id"
    t.index ["number"], name: "index_master_bls_on_number", unique: true
  end

  create_table "movement_pass_vehicles", force: :cascade do |t|
    t.bigint "movement_pass_id", null: false
    t.string "role", null: false
    t.string "operator_name", null: false
    t.string "plate", null: false
    t.string "unit_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "carrier_id", null: false
    t.string "economic_number"
    t.index ["carrier_id"], name: "index_movement_pass_vehicles_on_carrier_id"
    t.index ["movement_pass_id", "role"], name: "index_movement_pass_vehicles_on_movement_pass_id_and_role", unique: true
    t.index ["movement_pass_id"], name: "index_movement_pass_vehicles_on_movement_pass_id"
    t.check_constraint "role::text = ANY (ARRAY['principal'::character varying::text, 'destino'::character varying::text])", name: "movement_pass_vehicles_role_check"
    t.check_constraint "unit_type::text = ANY (ARRAY['sencillo'::character varying::text, 'full'::character varying::text])", name: "movement_pass_vehicles_unit_type_check"
  end

  create_table "movement_passes", force: :cascade do |t|
    t.bigint "container_id", null: false
    t.bigint "container_assignment_id"
    t.bigint "carrier_id"
    t.bigint "client_id"
    t.bigint "requested_by_id"
    t.string "movement_type", null: false
    t.string "status", default: "vigente", null: false
    t.string "token", null: false
    t.string "load_status"
    t.datetime "issued_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "consumed_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "entered_at"
    t.datetime "exit_scanned_at"
    t.index ["carrier_id"], name: "index_movement_passes_on_carrier_id"
    t.index ["client_id"], name: "index_movement_passes_on_client_id"
    t.index ["container_assignment_id"], name: "index_movement_passes_on_container_assignment_id"
    t.index ["container_id", "movement_type"], name: "index_movement_passes_on_active_container_and_type", unique: true, where: "((status)::text = 'vigente'::text)"
    t.index ["container_id"], name: "index_movement_passes_on_container_id"
    t.index ["requested_by_id"], name: "index_movement_passes_on_requested_by_id"
    t.index ["status", "expires_at"], name: "index_movement_passes_on_status_and_expires_at"
    t.index ["token"], name: "index_movement_passes_on_token", unique: true
    t.check_constraint "load_status IS NULL OR (load_status::text = ANY (ARRAY['lleno'::character varying::text, 'vacio'::character varying::text]))", name: "movement_passes_load_status_check"
    t.check_constraint "movement_type::text = ANY (ARRAY['ingreso'::character varying::text, 'salida'::character varying::text, 'traspaleo'::character varying::text])", name: "movement_passes_type_check"
    t.check_constraint "status::text = ANY (ARRAY['vigente'::character varying::text, 'completado'::character varying::text, 'cancelado'::character varying::text, 'vencido'::character varying::text])", name: "movement_passes_status_check"
  end

  create_table "movement_plans", force: :cascade do |t|
    t.bigint "container_id", null: false
    t.bigint "movement_pass_id"
    t.bigint "created_by_id"
    t.bigint "origin_yard_slot_id"
    t.bigint "destination_yard_slot_id"
    t.string "movement_type", null: false
    t.string "status", default: "pendiente", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "work_schedule_id"
    t.index ["container_id"], name: "index_movement_plans_on_container_id"
    t.index ["container_id"], name: "index_movement_plans_on_pending_container", unique: true, where: "((status)::text = 'pendiente'::text)"
    t.index ["created_by_id"], name: "index_movement_plans_on_created_by_id"
    t.index ["destination_yard_slot_id"], name: "index_movement_plans_on_destination_yard_slot_id"
    t.index ["movement_pass_id"], name: "index_movement_plans_on_movement_pass_id", unique: true, where: "(movement_pass_id IS NOT NULL)"
    t.index ["origin_yard_slot_id"], name: "index_movement_plans_on_origin_yard_slot_id"
    t.index ["status"], name: "index_movement_plans_on_status"
    t.index ["work_schedule_id"], name: "index_movement_plans_on_work_schedule_id"
    t.check_constraint "movement_type::text = 'salida'::text AND movement_pass_id IS NOT NULL OR movement_type::text = 'reacomodo'::text AND movement_pass_id IS NULL AND destination_yard_slot_id IS NOT NULL", name: "movement_plans_target_valid"
    t.check_constraint "movement_type::text = ANY (ARRAY['salida'::character varying::text, 'reacomodo'::character varying::text])", name: "movement_plans_type_valid"
    t.check_constraint "status::text = ANY (ARRAY['pendiente'::character varying::text, 'completada'::character varying::text, 'cancelada'::character varying::text])", name: "movement_plans_status_valid"
  end

  create_table "rehandling_requests", force: :cascade do |t|
    t.bigint "movement_pass_id", null: false
    t.bigint "container_id", null: false
    t.bigint "created_by_id"
    t.string "status", default: "pendiente", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "movement_plan_id"
    t.index ["container_id"], name: "index_rehandling_requests_on_container_id"
    t.index ["created_by_id"], name: "index_rehandling_requests_on_created_by_id"
    t.index ["movement_pass_id"], name: "index_rehandling_requests_on_movement_pass_id"
    t.index ["movement_pass_id"], name: "index_rehandling_requests_on_pending_pass", unique: true, where: "((status)::text = 'pendiente'::text)"
    t.index ["movement_plan_id"], name: "index_rehandling_requests_on_movement_plan_id", unique: true
    t.index ["status"], name: "index_rehandling_requests_on_status"
    t.check_constraint "status::text = ANY (ARRAY['pendiente'::character varying::text, 'completada'::character varying::text, 'cancelada'::character varying::text])", name: "rehandling_requests_status_valid"
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

  create_table "warehouse_bays", force: :cascade do |t|
    t.integer "number", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["number"], name: "index_warehouse_bays_on_number", unique: true
    t.check_constraint "number >= 1 AND number <= 4", name: "warehouse_bays_number_valid"
  end

  create_table "warehouse_slots", force: :cascade do |t|
    t.bigint "warehouse_bay_id", null: false
    t.integer "number", null: false
    t.string "code", null: false
    t.string "qr_token", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_warehouse_slots_on_code", unique: true
    t.index ["qr_token"], name: "index_warehouse_slots_on_qr_token", unique: true
    t.index ["warehouse_bay_id", "number"], name: "index_warehouse_slots_on_warehouse_bay_id_and_number", unique: true
    t.index ["warehouse_bay_id"], name: "index_warehouse_slots_on_warehouse_bay_id"
    t.check_constraint "number >= 1 AND number <= 16", name: "warehouse_slots_number_valid"
  end

  create_table "work_orders", force: :cascade do |t|
    t.bigint "container_id", null: false
    t.bigint "movement_pass_id"
    t.bigint "from_yard_slot_id"
    t.bigint "to_yard_slot_id"
    t.bigint "created_by_id"
    t.bigint "completed_by_id"
    t.string "movement_type", null: false
    t.string "status", default: "pendiente", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "rehandling_request_id"
    t.bigint "movement_plan_id"
    t.bigint "work_schedule_id"
    t.index ["completed_by_id"], name: "index_work_orders_on_completed_by_id"
    t.index ["container_id"], name: "index_work_orders_on_container_id"
    t.index ["container_id"], name: "index_work_orders_on_container_id_pending", unique: true, where: "((status)::text = 'pendiente'::text)"
    t.index ["created_by_id"], name: "index_work_orders_on_created_by_id"
    t.index ["from_yard_slot_id"], name: "index_work_orders_on_from_yard_slot_id"
    t.index ["movement_pass_id"], name: "index_work_orders_on_movement_pass_id", unique: true, where: "(movement_pass_id IS NOT NULL)"
    t.index ["movement_plan_id"], name: "index_work_orders_on_movement_plan_id"
    t.index ["rehandling_request_id"], name: "index_work_orders_on_rehandling_request_id"
    t.index ["status"], name: "index_work_orders_on_status"
    t.index ["to_yard_slot_id"], name: "index_work_orders_on_to_yard_slot_id"
    t.index ["work_schedule_id"], name: "index_work_orders_on_work_schedule_id"
    t.check_constraint "movement_type::text = ANY (ARRAY['ingreso'::character varying::text, 'salida'::character varying::text, 'traspaleo'::character varying::text, 'reacomodo'::character varying::text])", name: "work_orders_type_valid"
    t.check_constraint "status::text = ANY (ARRAY['pendiente'::character varying::text, 'completada'::character varying::text, 'cancelada'::character varying::text])", name: "work_orders_status_valid"
  end

  create_table "work_schedules", force: :cascade do |t|
    t.bigint "master_bl_id"
    t.bigint "created_by_id"
    t.date "scheduled_for", null: false
    t.string "status", default: "activa", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_work_schedules_on_created_by_id"
    t.index ["master_bl_id"], name: "index_work_schedules_on_master_bl_id"
    t.index ["scheduled_for"], name: "index_work_schedules_on_scheduled_for"
    t.index ["status"], name: "index_work_schedules_on_status"
    t.check_constraint "status::text = ANY (ARRAY['activa'::character varying::text, 'completada'::character varying::text, 'cancelada'::character varying::text])", name: "work_schedules_status_valid"
  end

  create_table "yard_area_sections", force: :cascade do |t|
    t.bigint "yard_area_id", null: false
    t.bigint "master_bl_id"
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["master_bl_id"], name: "index_yard_area_sections_on_master_bl_id"
    t.index ["yard_area_id", "name"], name: "index_yard_area_sections_on_yard_area_id_and_name", unique: true
    t.index ["yard_area_id"], name: "index_yard_area_sections_on_yard_area_id"
  end

  create_table "yard_areas", force: :cascade do |t|
    t.bigint "yard_block_id", null: false
    t.bigint "client_id"
    t.string "code", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_yard_areas_on_client_id"
    t.index ["code"], name: "index_yard_areas_on_code", unique: true
    t.index ["yard_block_id"], name: "index_yard_areas_on_yard_block_id"
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
    t.bigint "yard_area_section_id"
    t.index ["code"], name: "index_yard_slots_on_code", unique: true
    t.index ["yard_area_section_id"], name: "index_yard_slots_on_yard_area_section_id"
    t.index ["yard_block_id", "bay", "row", "level"], name: "index_yard_slots_on_position", unique: true
    t.index ["yard_block_id"], name: "index_yard_slots_on_yard_block_id"
    t.check_constraint "bay > 0 AND level > 0 AND \"row\"::text ~ '^[A-Z]$'::text", name: "yard_slots_position_valid"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cargo_dispatch_allocations", "cargo_dispatch_instructions"
  add_foreign_key "cargo_dispatch_allocations", "cargo_dispatch_trips"
  add_foreign_key "cargo_dispatch_allocations", "cargo_items"
  add_foreign_key "cargo_dispatch_allocations", "users", column: "confirmed_by_id"
  add_foreign_key "cargo_dispatch_allocations", "users", column: "reported_by_id"
  add_foreign_key "cargo_dispatch_allocations", "warehouse_slots"
  add_foreign_key "cargo_dispatch_events", "cargo_dispatch_passes"
  add_foreign_key "cargo_dispatch_events", "cargo_dispatch_trips"
  add_foreign_key "cargo_dispatch_events", "users"
  add_foreign_key "cargo_dispatch_instruction_containers", "cargo_dispatch_instructions"
  add_foreign_key "cargo_dispatch_instruction_containers", "containers"
  add_foreign_key "cargo_dispatch_instructions", "cargo_dispatch_requests"
  add_foreign_key "cargo_dispatch_instructions", "cargo_packagings"
  add_foreign_key "cargo_dispatch_instructions", "containers"
  add_foreign_key "cargo_dispatch_passes", "cargo_dispatch_trips"
  add_foreign_key "cargo_dispatch_passes", "users", column: "requested_by_id"
  add_foreign_key "cargo_dispatch_requests", "clients"
  add_foreign_key "cargo_dispatch_requests", "users", column: "requested_by_id"
  add_foreign_key "cargo_dispatch_trips", "cargo_dispatch_requests"
  add_foreign_key "cargo_dispatch_trips", "carriers"
  add_foreign_key "cargo_dispatch_trips", "users", column: "created_by_id"
  add_foreign_key "cargo_item_movements", "cargo_items"
  add_foreign_key "cargo_item_movements", "users", on_delete: :nullify
  add_foreign_key "cargo_item_movements", "warehouse_slots", column: "from_slot_id"
  add_foreign_key "cargo_item_movements", "warehouse_slots", column: "to_slot_id"
  add_foreign_key "cargo_items", "cargo_manifests"
  add_foreign_key "cargo_items", "cargo_packagings"
  add_foreign_key "cargo_items", "warehouse_slots"
  add_foreign_key "cargo_manifest_events", "cargo_manifests"
  add_foreign_key "cargo_manifest_events", "users", on_delete: :nullify
  add_foreign_key "cargo_manifests", "clients"
  add_foreign_key "cargo_manifests", "containers"
  add_foreign_key "container_assignments", "carriers"
  add_foreign_key "container_assignments", "containers"
  add_foreign_key "container_assignments", "users", column: "assigned_by_id", on_delete: :nullify
  add_foreign_key "container_assignments", "yard_area_sections"
  add_foreign_key "container_assignments", "yard_areas"
  add_foreign_key "container_movements", "containers", on_delete: :restrict
  add_foreign_key "container_movements", "movement_passes", on_delete: :restrict
  add_foreign_key "container_movements", "users", on_delete: :nullify
  add_foreign_key "container_movements", "yard_slots", column: "from_yard_slot_id", on_delete: :restrict
  add_foreign_key "container_movements", "yard_slots", column: "to_yard_slot_id", on_delete: :restrict
  add_foreign_key "containers", "clients"
  add_foreign_key "containers", "master_bls"
  add_foreign_key "containers", "yard_slots", column: "current_yard_slot_id"
  add_foreign_key "deconsolidations", "containers"
  add_foreign_key "deconsolidations", "users", column: "created_by_id"
  add_foreign_key "master_bls", "clients"
  add_foreign_key "movement_pass_vehicles", "carriers"
  add_foreign_key "movement_pass_vehicles", "movement_passes", on_delete: :cascade
  add_foreign_key "movement_passes", "carriers"
  add_foreign_key "movement_passes", "clients"
  add_foreign_key "movement_passes", "container_assignments"
  add_foreign_key "movement_passes", "containers"
  add_foreign_key "movement_passes", "users", column: "requested_by_id", on_delete: :nullify
  add_foreign_key "movement_plans", "containers", on_delete: :restrict
  add_foreign_key "movement_plans", "movement_passes", on_delete: :restrict
  add_foreign_key "movement_plans", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "movement_plans", "work_schedules", on_delete: :restrict
  add_foreign_key "movement_plans", "yard_slots", column: "destination_yard_slot_id", on_delete: :restrict
  add_foreign_key "movement_plans", "yard_slots", column: "origin_yard_slot_id", on_delete: :restrict
  add_foreign_key "rehandling_requests", "containers", on_delete: :restrict
  add_foreign_key "rehandling_requests", "movement_passes", on_delete: :restrict
  add_foreign_key "rehandling_requests", "movement_plans", on_delete: :restrict
  add_foreign_key "rehandling_requests", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "users", "carriers"
  add_foreign_key "users", "clients"
  add_foreign_key "warehouse_slots", "warehouse_bays"
  add_foreign_key "work_orders", "containers", on_delete: :restrict
  add_foreign_key "work_orders", "movement_passes", on_delete: :restrict
  add_foreign_key "work_orders", "movement_plans", on_delete: :restrict
  add_foreign_key "work_orders", "rehandling_requests", on_delete: :restrict
  add_foreign_key "work_orders", "users", column: "completed_by_id", on_delete: :nullify
  add_foreign_key "work_orders", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "work_orders", "work_schedules", on_delete: :restrict
  add_foreign_key "work_orders", "yard_slots", column: "from_yard_slot_id", on_delete: :restrict
  add_foreign_key "work_orders", "yard_slots", column: "to_yard_slot_id", on_delete: :restrict
  add_foreign_key "work_schedules", "master_bls", on_delete: :restrict
  add_foreign_key "work_schedules", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "yard_area_sections", "master_bls"
  add_foreign_key "yard_area_sections", "yard_areas"
  add_foreign_key "yard_areas", "clients"
  add_foreign_key "yard_areas", "yard_blocks"
  add_foreign_key "yard_slots", "yard_area_sections", on_delete: :nullify
  add_foreign_key "yard_slots", "yard_blocks"
end

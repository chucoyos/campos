class CreateCargoDispatches < ActiveRecord::Migration[8.1]
  def change
    create_table :cargo_dispatch_requests do |t|
      t.references :client, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :destination, null: false
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
    add_check_constraint :cargo_dispatch_requests, "status IN ('pending', 'in_progress', 'completed', 'cancelled')",
      name: "cargo_dispatch_requests_status_valid"

    create_table :cargo_dispatch_instructions do |t|
      t.references :cargo_dispatch_request, null: false, foreign_key: true, index: { name: "index_dispatch_instructions_on_request" }
      t.references :container, foreign_key: true
      t.references :cargo_packaging, foreign_key: true
      t.string :criterion, null: false
      t.integer :quantity
      t.decimal :weight_kg, precision: 12, scale: 3
      t.timestamps
    end
    add_check_constraint :cargo_dispatch_instructions, "criterion IN ('all', 'half', 'quantity', 'weight')",
      name: "cargo_dispatch_instructions_criterion_valid"
    add_check_constraint :cargo_dispatch_instructions,
      "(criterion IN ('all', 'half') AND container_id IS NOT NULL AND cargo_packaging_id IS NULL AND quantity IS NULL AND weight_kg IS NULL) OR " \
      "(criterion = 'quantity' AND cargo_packaging_id IS NOT NULL AND quantity IS NOT NULL AND quantity > 0 AND weight_kg IS NULL) OR " \
      "(criterion = 'weight' AND quantity IS NULL AND weight_kg IS NOT NULL AND weight_kg > 0)",
      name: "cargo_dispatch_instructions_details_valid"

    create_table :cargo_dispatch_trips do |t|
      t.references :cargo_dispatch_request, null: false, foreign_key: true, index: { name: "index_dispatch_trips_on_request" }
      t.references :carrier, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :origin_type, null: false
      t.string :status, null: false, default: "pending"
      t.string :transport_name
      t.timestamps
    end
    add_check_constraint :cargo_dispatch_trips, "origin_type IN ('mbl', 'general')",
      name: "cargo_dispatch_trips_origin_valid"
    add_check_constraint :cargo_dispatch_trips, "status IN ('pending', 'prepared', 'in_yard', 'loaded', 'completed', 'cancelled')",
      name: "cargo_dispatch_trips_status_valid"
    add_check_constraint :cargo_dispatch_trips,
      "(origin_type = 'mbl' AND transport_name IS NULL) OR (origin_type = 'general' AND carrier_id IS NULL)",
      name: "cargo_dispatch_trips_transport_valid"

    create_table :cargo_dispatch_allocations do |t|
      t.references :cargo_dispatch_trip, null: false, foreign_key: true, index: { name: "index_dispatch_allocations_on_trip" }
      t.references :cargo_dispatch_instruction, null: false, foreign_key: true, index: { name: "index_dispatch_allocations_on_instruction" }
      t.references :cargo_item, null: false, foreign_key: true
      t.integer :reserved_quantity, null: false
      t.integer :reported_quantity, null: false, default: 0
      t.integer :loaded_quantity, null: false, default: 0
      t.string :status, null: false, default: "reserved"
      t.references :warehouse_slot, foreign_key: true
      t.string :slot_section, limit: 1
      t.references :confirmed_by, foreign_key: { to_table: :users }
      t.datetime :confirmed_at
      t.timestamps
    end
    add_index :cargo_dispatch_allocations, [ :cargo_dispatch_trip_id, :cargo_dispatch_instruction_id, :cargo_item_id ],
      unique: true, name: "index_dispatch_allocations_on_trip_instruction_item"
    add_check_constraint :cargo_dispatch_allocations,
      "reserved_quantity > 0 AND reported_quantity >= 0 AND reported_quantity <= reserved_quantity AND " \
      "loaded_quantity >= 0 AND loaded_quantity <= reported_quantity",
      name: "cargo_dispatch_allocations_quantities_valid"
    add_check_constraint :cargo_dispatch_allocations, "status IN ('reserved', 'confirmed', 'released')",
      name: "cargo_dispatch_allocations_status_valid"
    add_check_constraint :cargo_dispatch_allocations,
      "(warehouse_slot_id IS NULL AND slot_section IS NULL) OR " \
      "(warehouse_slot_id IS NOT NULL AND slot_section IS NOT NULL AND slot_section IN ('A', 'B', 'C'))",
      name: "cargo_dispatch_allocations_location_valid"
  end
end

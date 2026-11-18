class AddCargoDispatchOperations < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :cargo_items, name: "cargo_items_status_valid"
    add_check_constraint :cargo_items, "status IN ('captured', 'stored', 'dispatched')",
      name: "cargo_items_status_valid"

    add_reference :cargo_dispatch_allocations, :reported_by, foreign_key: { to_table: :users }
    add_column :cargo_dispatch_allocations, :reported_at, :datetime

    create_table :cargo_dispatch_passes do |t|
      t.references :cargo_dispatch_trip, null: false, foreign_key: true, index: { name: "index_dispatch_passes_on_trip" }
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :token, null: false
      t.string :status, null: false, default: "active"
      t.string :operator_name, null: false
      t.string :plate, null: false
      t.string :economic_number
      t.string :unit_type, null: false
      t.datetime :issued_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :entered_at
      t.datetime :exit_scanned_at
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :cargo_dispatch_passes, :token, unique: true
    add_index :cargo_dispatch_passes, :cargo_dispatch_trip_id, unique: true, where: "status = 'active'",
      name: "index_dispatch_passes_on_active_trip"
    add_check_constraint :cargo_dispatch_passes, "status IN ('active', 'completed', 'cancelled', 'expired')",
      name: "cargo_dispatch_passes_status_valid"
    add_check_constraint :cargo_dispatch_passes, "unit_type IN ('sencillo', 'full')",
      name: "cargo_dispatch_passes_unit_type_valid"

    create_table :cargo_dispatch_events do |t|
      t.references :cargo_dispatch_trip, null: false, foreign_key: true, index: { name: "index_dispatch_events_on_trip" }
      t.references :user, null: false, foreign_key: true
      t.references :cargo_dispatch_pass, foreign_key: true, index: { name: "index_dispatch_events_on_pass" }
      t.string :event, null: false
      t.text :details
      t.datetime :created_at, null: false
    end
  end

  def down
    drop_table :cargo_dispatch_events
    drop_table :cargo_dispatch_passes
    remove_column :cargo_dispatch_allocations, :reported_at
    remove_reference :cargo_dispatch_allocations, :reported_by, foreign_key: { to_table: :users }
    remove_check_constraint :cargo_items, name: "cargo_items_status_valid"
    add_check_constraint :cargo_items, "status IN ('captured', 'stored')",
      name: "cargo_items_status_valid"
  end
end

class CreateWarehouseLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :warehouse_bays do |t|
      t.integer :number, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :warehouse_bays, :number, unique: true
    add_check_constraint :warehouse_bays, "number BETWEEN 1 AND 4", name: "warehouse_bays_number_valid"

    create_table :warehouse_slots do |t|
      t.references :warehouse_bay, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :code, null: false
      t.string :qr_token, null: false
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :warehouse_slots, :code, unique: true
    add_index :warehouse_slots, :qr_token, unique: true
    add_index :warehouse_slots, [ :warehouse_bay_id, :number ], unique: true
    add_check_constraint :warehouse_slots, "number BETWEEN 1 AND 16", name: "warehouse_slots_number_valid"

    change_table :cargo_items do |t|
      t.references :warehouse_slot, foreign_key: true
      t.string :slot_section, limit: 1
      t.string :status, null: false, default: "captured"
    end
    add_check_constraint :cargo_items, "status IN ('captured', 'stored')", name: "cargo_items_status_valid"
    add_check_constraint :cargo_items, "slot_section IN ('A', 'B', 'C')", name: "cargo_items_slot_section_valid"
    add_check_constraint :cargo_items,
      "(warehouse_slot_id IS NULL) = (slot_section IS NULL) AND (status = 'stored') = (warehouse_slot_id IS NOT NULL)",
      name: "cargo_items_location_consistent"

    create_table :cargo_item_movements do |t|
      t.references :cargo_item, null: false, foreign_key: true
      t.references :from_slot, foreign_key: { to_table: :warehouse_slots }
      t.string :from_section, limit: 1
      t.references :to_slot, null: false, foreign_key: { to_table: :warehouse_slots }
      t.string :to_section, limit: 1, null: false
      t.references :user, foreign_key: { on_delete: :nullify }
      t.datetime :created_at, null: false
    end
    add_index :cargo_item_movements, [ :cargo_item_id, :created_at ]
  end
end

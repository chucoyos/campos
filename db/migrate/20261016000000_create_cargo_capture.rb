class CreateCargoCapture < ActiveRecord::Migration[8.1]
  def up
    create_table :cargo_packagings do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :tracking_mode, null: false
      t.boolean :weight_required, null: false, default: false
      t.boolean :origin_identifier_allowed, null: false, default: false
      t.boolean :qr_allowed, null: false, default: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :cargo_packagings, :code, unique: true
    add_check_constraint :cargo_packagings, "tracking_mode IN ('individual', 'aggregate')", name: "cargo_packagings_tracking_mode_valid"
    add_check_constraint :cargo_packagings, "tracking_mode = 'individual' OR (weight_required = FALSE AND origin_identifier_allowed = FALSE AND qr_allowed = FALSE)", name: "cargo_packagings_aggregate_capabilities_valid"
    add_check_constraint :cargo_packagings, "tracking_mode = 'aggregate' OR weight_required = TRUE", name: "cargo_packagings_individual_weight_required"

    create_table :cargo_manifests do |t|
      t.references :client, null: false, foreign_key: true
      t.references :container, foreign_key: true, index: false
      t.string :status, null: false, default: "draft"
      t.datetime :confirmed_at
      t.timestamps
    end
    add_index :cargo_manifests, :container_id, unique: true, where: "container_id IS NOT NULL"
    add_check_constraint :cargo_manifests, "status IN ('draft', 'confirmed')", name: "cargo_manifests_status_valid"

    create_table :cargo_items do |t|
      t.references :cargo_manifest, null: false, foreign_key: true
      t.references :cargo_packaging, null: false, foreign_key: true
      t.string :description, null: false
      t.integer :quantity, null: false, default: 1
      t.decimal :weight_kg, precision: 12, scale: 3
      t.string :origin_identifier
      t.string :qr_token
      t.timestamps
    end
    add_index :cargo_items, :qr_token, unique: true, where: "qr_token IS NOT NULL"
    add_check_constraint :cargo_items, "quantity > 0", name: "cargo_items_quantity_positive"
    add_check_constraint :cargo_items, "weight_kg IS NULL OR weight_kg > 0", name: "cargo_items_weight_positive"

    execute <<~SQL
      INSERT INTO cargo_packagings
        (code, name, tracking_mode, weight_required, origin_identifier_allowed, qr_allowed, active, created_at, updated_at)
      VALUES
        ('pallet', 'Pallet', 'individual', TRUE, FALSE, TRUE, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('roll', 'Rollo', 'individual', TRUE, TRUE, TRUE, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
        ('box', 'Caja', 'aggregate', FALSE, FALSE, FALSE, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def down
    drop_table :cargo_items
    drop_table :cargo_manifests
    drop_table :cargo_packagings
  end
end

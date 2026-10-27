class CreateContainerMovements < ActiveRecord::Migration[8.1]
  def change
    add_reference :containers, :current_yard_slot, foreign_key: { to_table: :yard_slots },
      index: { unique: true, where: "current_yard_slot_id IS NOT NULL" }

    create_table :container_movements do |t|
      t.references :container, null: false, foreign_key: { on_delete: :restrict }
      t.references :movement_pass, index: false, foreign_key: { on_delete: :restrict }
      t.references :from_yard_slot, foreign_key: { to_table: :yard_slots, on_delete: :restrict }
      t.references :to_yard_slot, foreign_key: { to_table: :yard_slots, on_delete: :restrict }
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :movement_type, null: false
      t.string :load_status
      t.datetime :created_at, null: false
    end

    add_index :container_movements, %i[container_id created_at]
    add_index :container_movements, :movement_pass_id, unique: true, where: "movement_pass_id IS NOT NULL"
    add_check_constraint :container_movements,
      "movement_type IN ('ingreso', 'salida', 'traspaleo', 'reacomodo')",
      name: "container_movements_type_valid"
    add_check_constraint :container_movements,
      "load_status IS NULL OR load_status IN ('lleno', 'vacio')",
      name: "container_movements_load_status_valid"
    add_check_constraint :container_movements,
      "(movement_type = 'ingreso' AND from_yard_slot_id IS NULL AND to_yard_slot_id IS NOT NULL) OR " \
      "(movement_type = 'salida' AND from_yard_slot_id IS NOT NULL AND to_yard_slot_id IS NULL) OR " \
      "(movement_type = 'traspaleo' AND from_yard_slot_id IS NULL AND to_yard_slot_id IS NULL) OR " \
      "(movement_type = 'reacomodo' AND from_yard_slot_id IS NOT NULL AND to_yard_slot_id IS NOT NULL)",
      name: "container_movements_slots_valid"
    add_check_constraint :container_movements,
      "(movement_type = 'reacomodo' AND movement_pass_id IS NULL) OR " \
      "(movement_type <> 'reacomodo' AND movement_pass_id IS NOT NULL)",
      name: "container_movements_pass_valid"
  end
end

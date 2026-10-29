class CreateWorkOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :work_orders do |t|
      t.references :container, null: false, foreign_key: { on_delete: :restrict }
      t.references :movement_pass, index: false, foreign_key: { on_delete: :restrict }
      t.references :from_yard_slot, foreign_key: { to_table: :yard_slots, on_delete: :restrict }
      t.references :to_yard_slot, foreign_key: { to_table: :yard_slots, on_delete: :restrict }
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :completed_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :movement_type, null: false
      t.string :status, null: false, default: "pendiente"
      t.datetime :completed_at
      t.timestamps
    end

    add_index :work_orders, :status
    add_index :work_orders, :movement_pass_id, unique: true, where: "movement_pass_id IS NOT NULL"
    add_index :work_orders, :container_id, unique: true, where: "status = 'pendiente'",
      name: "index_work_orders_on_container_id_pending"
    add_check_constraint :work_orders,
      "movement_type IN ('ingreso', 'salida', 'traspaleo', 'reacomodo')",
      name: "work_orders_type_valid"
    add_check_constraint :work_orders,
      "status IN ('pendiente', 'completada', 'cancelada')",
      name: "work_orders_status_valid"
  end
end

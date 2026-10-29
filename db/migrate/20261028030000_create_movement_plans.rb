class CreateMovementPlans < ActiveRecord::Migration[8.1]
  def up
    create_table :movement_plans do |t|
      t.references :container, null: false, foreign_key: { on_delete: :restrict }
      t.references :movement_pass, foreign_key: { on_delete: :restrict }, index: false
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :origin_yard_slot, foreign_key: { to_table: :yard_slots, on_delete: :restrict }
      t.references :destination_yard_slot, foreign_key: { to_table: :yard_slots, on_delete: :restrict }
      t.string :movement_type, null: false
      t.string :status, null: false, default: "pendiente"
      t.timestamps
    end

    add_index :movement_plans, :movement_pass_id, unique: true,
      where: "movement_pass_id IS NOT NULL", name: "index_movement_plans_on_movement_pass_id"
    add_index :movement_plans, :container_id, unique: true,
      where: "status = 'pendiente'", name: "index_movement_plans_on_pending_container"
    add_index :movement_plans, :status
    add_check_constraint :movement_plans, "movement_type IN ('salida', 'reacomodo')",
      name: "movement_plans_type_valid"
    add_check_constraint :movement_plans, "status IN ('pendiente', 'completada', 'cancelada')",
      name: "movement_plans_status_valid"
    add_check_constraint :movement_plans,
      "(movement_type = 'salida' AND movement_pass_id IS NOT NULL) OR (movement_type = 'reacomodo' AND movement_pass_id IS NULL AND destination_yard_slot_id IS NOT NULL)",
      name: "movement_plans_target_valid"

    add_reference :work_orders, :movement_plan, foreign_key: { on_delete: :restrict }
    add_reference :rehandling_requests, :movement_plan, foreign_key: { on_delete: :restrict }, index: false
    add_index :rehandling_requests, :movement_plan_id, unique: true

    execute <<~SQL.squish
      INSERT INTO movement_plans
        (container_id, movement_pass_id, created_by_id, origin_yard_slot_id, movement_type, status, created_at, updated_at)
      SELECT requests.container_id, requests.movement_pass_id, requests.created_by_id,
             COALESCE(
               (SELECT work_orders.from_yard_slot_id FROM work_orders
                WHERE work_orders.rehandling_request_id = requests.id
                ORDER BY work_orders.id LIMIT 1),
               containers.current_yard_slot_id
             ),
             'salida', requests.status, requests.created_at, requests.updated_at
      FROM rehandling_requests requests
      JOIN containers ON containers.id = requests.container_id
    SQL

    execute <<~SQL.squish
      UPDATE rehandling_requests
      SET movement_plan_id = movement_plans.id
      FROM movement_plans
      WHERE movement_plans.movement_pass_id = rehandling_requests.movement_pass_id
    SQL

    execute <<~SQL.squish
      UPDATE work_orders
      SET movement_plan_id = rehandling_requests.movement_plan_id
      FROM rehandling_requests
      WHERE work_orders.rehandling_request_id = rehandling_requests.id
    SQL
  end

  def down
    remove_reference :rehandling_requests, :movement_plan, foreign_key: true
    remove_reference :work_orders, :movement_plan, foreign_key: true
    drop_table :movement_plans
  end
end

class CreateMovementPasses < ActiveRecord::Migration[8.1]
  def change
    create_table :movement_passes do |t|
      t.references :container, null: false, foreign_key: true
      t.references :container_assignment, foreign_key: true
      t.references :carrier, foreign_key: true
      t.references :client, foreign_key: true
      t.references :requested_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :movement_type, null: false
      t.string :status, null: false, default: "vigente"
      t.string :token, null: false
      t.string :load_status
      t.datetime :issued_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :movement_passes, :token, unique: true
    add_index :movement_passes, %i[status expires_at]
    add_index :movement_passes, %i[container_id movement_type], unique: true, where: "status = 'vigente'",
              name: "index_movement_passes_on_active_container_and_type"
    add_check_constraint :movement_passes, "movement_type IN ('ingreso', 'salida', 'traspaleo')", name: "movement_passes_type_check"
    add_check_constraint :movement_passes, "status IN ('vigente', 'completado', 'cancelado', 'vencido')", name: "movement_passes_status_check"
    add_check_constraint :movement_passes, "load_status IS NULL OR load_status IN ('lleno', 'vacio')", name: "movement_passes_load_status_check"

    create_table :movement_pass_vehicles do |t|
      t.references :movement_pass, null: false, foreign_key: { on_delete: :cascade }
      t.string :role, null: false
      t.string :company_name, null: false
      t.string :operator_name, null: false
      t.string :plate, null: false
      t.string :unit_type, null: false

      t.timestamps
    end

    add_index :movement_pass_vehicles, %i[movement_pass_id role], unique: true
    add_check_constraint :movement_pass_vehicles, "role IN ('principal', 'destino')", name: "movement_pass_vehicles_role_check"
    add_check_constraint :movement_pass_vehicles, "unit_type IN ('sencillo', 'full')", name: "movement_pass_vehicles_unit_type_check"
  end
end

class CreateContainerAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :container_assignments do |t|
      t.references :container, null: false, foreign_key: true
      t.references :carrier, null: false, foreign_key: true
      t.references :assigned_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :yard_area, foreign_key: true
      t.references :yard_area_section, foreign_key: true
      t.string :operation, null: false
      t.string :status, null: false, default: "pendiente"
      t.integer :preferred_level
      t.timestamps
    end

    add_index :container_assignments, %i[container_id operation], unique: true, where: "status = 'pendiente'",
              name: "index_container_assignments_open_unique"
    add_check_constraint :container_assignments, "operation IN ('ingreso', 'salida')", name: "container_assignments_operation_valid"
    add_check_constraint :container_assignments, "preferred_level IS NULL OR preferred_level > 0", name: "container_assignments_level_positive"
  end
end

class CreateWorkSchedules < ActiveRecord::Migration[8.1]
  def change
    create_table :work_schedules do |t|
      t.references :master_bl, foreign_key: { on_delete: :restrict }
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.date :scheduled_for, null: false
      t.string :status, null: false, default: "activa"
      t.text :notes
      t.timestamps
    end

    add_index :work_schedules, :status
    add_index :work_schedules, :scheduled_for
    add_check_constraint :work_schedules, "status IN ('activa', 'completada', 'cancelada')",
      name: "work_schedules_status_valid"

    add_reference :work_orders, :work_schedule, foreign_key: { on_delete: :restrict }
    add_reference :movement_plans, :work_schedule, foreign_key: { on_delete: :restrict }
  end
end

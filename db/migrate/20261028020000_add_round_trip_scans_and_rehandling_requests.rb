class AddRoundTripScansAndRehandlingRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :movement_passes, :entered_at, :datetime
    add_column :movement_passes, :exit_scanned_at, :datetime

    create_table :rehandling_requests do |t|
      t.references :movement_pass, null: false, foreign_key: { on_delete: :restrict }
      t.references :container, null: false, foreign_key: { on_delete: :restrict }
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :status, null: false, default: "pendiente"
      t.timestamps
    end

    add_index :rehandling_requests, :movement_pass_id, unique: true,
      where: "status = 'pendiente'", name: "index_rehandling_requests_on_pending_pass"
    add_index :rehandling_requests, :status
    add_check_constraint :rehandling_requests,
      "status IN ('pendiente', 'completada', 'cancelada')",
      name: "rehandling_requests_status_valid"

    add_reference :work_orders, :rehandling_request, foreign_key: { on_delete: :restrict }
  end
end

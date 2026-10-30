class CreateDeconsolidations < ActiveRecord::Migration[8.1]
  def change
    create_table :deconsolidations do |t|
      t.references :container, null: false, foreign_key: true, index: { unique: true }
      t.references :created_by, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "apertura"
      t.datetime :started_at
      t.datetime :emptied_at
      t.timestamps
    end

    add_index :deconsolidations, :status
    add_check_constraint :deconsolidations, "status IN ('apertura', 'desconsolidando', 'vaciado')", name: "deconsolidations_status_valid"
  end
end

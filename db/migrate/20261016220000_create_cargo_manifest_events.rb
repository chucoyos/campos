class CreateCargoManifestEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :cargo_manifest_events do |t|
      t.references :cargo_manifest, null: false, foreign_key: true
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :event, null: false
      t.string :from_status, null: false
      t.string :to_status, null: false
      t.datetime :created_at, null: false
    end
    add_index :cargo_manifest_events, [ :cargo_manifest_id, :created_at ]
    add_check_constraint :cargo_manifest_events, "event IN ('confirm', 'reopen')", name: "cargo_manifest_events_event_valid"
  end
end

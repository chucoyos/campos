class AddExitEvidenceEligibilityToCargoDispatchTrips < ActiveRecord::Migration[8.1]
  def change
    add_column :cargo_dispatch_trips, :exit_evidence_enabled, :boolean, null: false, default: false
    change_column_default :cargo_dispatch_trips, :exit_evidence_enabled, from: false, to: true
  end
end

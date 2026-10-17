class RemoveOriginIdentifierAllowedFromCargoPackagings < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :cargo_packagings, name: "cargo_packagings_aggregate_capabilities_valid"
    remove_column :cargo_packagings, :origin_identifier_allowed
    add_check_constraint :cargo_packagings, "tracking_mode = 'individual' OR (weight_required = FALSE AND qr_allowed = FALSE)", name: "cargo_packagings_aggregate_capabilities_valid"
  end

  def down
    remove_check_constraint :cargo_packagings, name: "cargo_packagings_aggregate_capabilities_valid"
    add_column :cargo_packagings, :origin_identifier_allowed, :boolean, null: false, default: false
    add_check_constraint :cargo_packagings, "tracking_mode = 'individual' OR (weight_required = FALSE AND origin_identifier_allowed = FALSE AND qr_allowed = FALSE)", name: "cargo_packagings_aggregate_capabilities_valid"
  end
end

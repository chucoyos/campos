class AddTransportModeToCargoDispatchTrips < ActiveRecord::Migration[8.1]
  def up
    add_column :cargo_dispatch_trips, :transport_mode, :string, null: false, default: "assigned"
    execute "UPDATE cargo_dispatch_trips SET transport_mode = 'customer' WHERE origin_type = 'general'"
    remove_check_constraint :cargo_dispatch_trips, name: "cargo_dispatch_trips_transport_valid"
    add_check_constraint :cargo_dispatch_trips,
      "(transport_mode = 'assigned' AND transport_name IS NULL) OR " \
      "(transport_mode = 'customer' AND origin_type = 'general' AND carrier_id IS NULL)",
      name: "cargo_dispatch_trips_transport_valid"
  end

  def down
    remove_check_constraint :cargo_dispatch_trips, name: "cargo_dispatch_trips_transport_valid"
    add_check_constraint :cargo_dispatch_trips,
      "(origin_type = 'mbl' AND transport_name IS NULL) OR (origin_type = 'general' AND carrier_id IS NULL)",
      name: "cargo_dispatch_trips_transport_valid"
    remove_column :cargo_dispatch_trips, :transport_mode
  end
end

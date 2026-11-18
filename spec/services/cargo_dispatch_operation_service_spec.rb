require "rails_helper"

RSpec.describe CargoDispatchOperationService do
  let(:client) { create(:client) }
  let(:admin) { create(:user, :admin) }
  let(:operator) { create(:user, :montacargas) }
  let(:request) { CargoDispatchRequest.create!(client: client, requested_by: admin, destination: "Destino") }
  let(:packaging) { create(:cargo_packaging, :box) }
  let(:instruction) { request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 10) }
  let(:trip) { request.trips.create!(origin_type: "general", transport_mode: "customer", transport_name: "Propio", created_by: admin) }
  let(:item) do
    manifest = create(:cargo_manifest, client: client)
    line = create(:cargo_item, cargo_manifest: manifest, cargo_packaging: packaging, quantity: 10, weight_kg: nil)
    manifest.confirm_by!(admin)
    line.store_at!(create(:warehouse_slot), "A", admin)
    line
  end
  let(:allocation) do
    CargoDispatchReservationService.call(trip: trip, selections: [ { cargo_item_id: item.id, instruction_id: instruction.id, quantity: 10 } ])
    trip.allocations.first
  end
  let(:pass) do
    allocation
    trip.prepare!
    trip.passes.create!(requested_by: admin, operator_name: "Operador", plate: "ABC123", unit_type: "sencillo")
  end

  it "requires confirmation before exit and preserves the remaining quantity on partial loading" do
    described_class.enter!(pass: pass, user: admin)
    expect { described_class.exit!(pass: pass, user: admin) }
      .to raise_error(described_class::Error, I18n.t("cargo_dispatch.errors.loading_unconfirmed"))

    described_class.report!(trip: trip, allocation: allocation, quantity: 4, user: operator)
    described_class.confirm!(trip: trip, user: admin)
    expect(allocation.reload).to have_attributes(status: "confirmed", loaded_quantity: 4, reported_by: operator)
    expect(item.reload).to be_stored

    pass.update!(exit_scanned_at: Time.current)
    described_class.exit!(pass: pass, user: admin)
    expect(trip.reload).to be_completed
    expect(pass.reload).to be_completed
  end

  it "removes a fully loaded item from the warehouse without erasing its history" do
    described_class.enter!(pass: pass, user: admin)
    described_class.report!(trip: trip, allocation: allocation, quantity: 10, user: operator)
    described_class.confirm!(trip: trip, user: admin)

    expect(item.reload).to be_dispatched
    expect(item.warehouse_slot).to be_nil
    expect(allocation.reload.warehouse_slot).to be_present
  end

  it "requires an explanation when nothing was loaded" do
    described_class.enter!(pass: pass, user: admin)

    expect { described_class.confirm!(trip: trip, user: admin) }
      .to raise_error(described_class::Error, I18n.t("cargo_dispatch.errors.reason_required"))
    described_class.confirm!(trip: trip, user: admin, reason: "Camión sin carga")
    expect(allocation.reload.status).to eq("released")
    expect(item.reload).to be_stored
  end

  it "releases the unused portion for a later trip" do
    described_class.enter!(pass: pass, user: admin)
    described_class.report!(trip: trip, allocation: allocation, quantity: 4, user: operator)
    described_class.confirm!(trip: trip, user: admin)
    later_trip = request.trips.create!(origin_type: "general", transport_mode: "customer", transport_name: "Propio", created_by: admin)

    expect {
      CargoDispatchReservationService.call(trip: later_trip, selections: [ { cargo_item_id: item.id, instruction_id: instruction.id, quantity: 6 } ])
    }.to change { later_trip.allocations.count }.by(1)
  end

  it "cancels a prepared trip and releases its reservations without deleting history" do
    pass
    described_class.cancel!(trip: trip, user: admin)

    expect(trip.reload).to be_cancelled
    expect(pass.reload).to be_cancelled
    expect(allocation.reload).to be_released
    expect(trip.events.last.event).to eq("trip_cancelled")
  end

  it "cannot cancel a trip after entry" do
    described_class.enter!(pass: pass, user: admin)

    expect { described_class.cancel!(trip: trip, user: admin) }
      .to raise_error(described_class::Error, I18n.t("cargo_dispatch.errors.cannot_cancel"))
    expect(allocation.reload).to be_reserved
  end
end

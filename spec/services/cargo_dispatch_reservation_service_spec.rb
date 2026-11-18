require "rails_helper"

RSpec.describe CargoDispatchReservationService do
  let(:client) { create(:client) }
  let(:user) { create(:user, :admin) }
  let(:request) { CargoDispatchRequest.create!(client: client, requested_by: user, destination: "Destino") }
  let(:packaging) { create(:cargo_packaging, :box) }
  let(:instruction) do
    request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 10)
  end
  let(:trip) { request.trips.create!(origin_type: "general", created_by: user) }
  let(:item) do
    manifest = create(:cargo_manifest, client: client)
    line = create(:cargo_item, cargo_manifest: manifest, cargo_packaging: packaging, quantity: 10, weight_kg: nil)
    manifest.confirm_by!(user)
    line.store_at!(create(:warehouse_slot), "A", user)
    line
  end

  def reserve(trip, instruction, item, quantity)
    described_class.call(trip: trip, selections: [ { instruction_id: instruction.id, cargo_item_id: item.id, quantity: quantity } ])
  end

  it "reserves part of an aggregate and rejects overbooking across trips" do
    reserve(trip, instruction, item, 6)
    other_trip = request.trips.create!(origin_type: "general", created_by: user)
    other_instruction = request.instructions.create!(criterion: "quantity", cargo_packaging: packaging, quantity: 10)

    expect { reserve(other_trip, other_instruction, item, 5) }
      .to raise_error(described_class::Error, I18n.t("cargo_dispatch.errors.insufficient_stock"))
    expect(item.dispatch_allocations.sum(:reserved_quantity)).to eq(6)
  end

  it "limits reservations across trips to the requested quantity" do
    reserve(trip, instruction, item, 6)
    other_trip = request.trips.create!(origin_type: "general", created_by: user)
    other_manifest = create(:cargo_manifest, client: client)
    other_item = create(:cargo_item, cargo_manifest: other_manifest, cargo_packaging: packaging, quantity: 10, weight_kg: nil)
    other_manifest.confirm_by!(user)
    other_item.store_at!(create(:warehouse_slot, warehouse_bay: create(:warehouse_bay, number: 2)), "A", user)

    expect { reserve(other_trip, instruction, other_item, 5) }
      .to raise_error(described_class::Error, I18n.t("cargo_dispatch.errors.request_exceeded"))
  end

  it "allows admin to fulfill a quantity target from an unselected MBL of the same client" do
    preferred_master_bl = create(:master_bl, client: client)
    preferred_container = create(:container, :with_master_bl, master_bl: preferred_master_bl)
    target = request.instructions.create!(
      criterion: "quantity", cargo_packaging: packaging, quantity: 7, preferred_containers: [ preferred_container ]
    )

    other_master_bl = create(:master_bl, client: client)
    other_container = create(:container, :with_master_bl, master_bl: other_master_bl)
    manifest = create(:cargo_manifest, client: client, container: other_container)
    item = create(:cargo_item, cargo_manifest: manifest, cargo_packaging: packaging, quantity: 7, weight_kg: nil)
    manifest.confirm_by!(user)
    item.store_at!(create(:warehouse_slot), "A", user)
    mbl_trip = request.trips.create!(origin_type: "mbl", created_by: user)

    reserve(mbl_trip, target, item, 7)

    expect(mbl_trip.allocations.sole).to have_attributes(cargo_item: item, reserved_quantity: 7)
    expect(target.preferred_containers).to contain_exactly(preferred_container)
  end

  it "rejects mixing MBL merchandise into a general cargo trip" do
    master_bl = create(:master_bl, client: client)
    container = create(:container, :with_master_bl, master_bl: master_bl)
    manifest = create(:cargo_manifest, client: client, container: container)
    line = create(:cargo_item, cargo_manifest: manifest, cargo_packaging: packaging, quantity: 2, weight_kg: nil)
    manifest.confirm_by!(user)
    line.store_at!(create(:warehouse_slot), "A", user)

    expect { reserve(trip, instruction, line, 1) }
      .to raise_error(described_class::Error, I18n.t("cargo_dispatch.errors.invalid_item"))
    expect(trip.allocations).to be_empty
  end

  it "allows general cargo trips with an assigned carrier or the customer's transport" do
    carrier = create(:carrier)
    expect(request.trips.build(origin_type: "general", transport_mode: "assigned", carrier: carrier, created_by: user)).to be_valid
    expect(request.trips.build(origin_type: "general", transport_mode: "customer", transport_name: "Transporte propio", created_by: user)).to be_valid
    expect(request.trips.build(origin_type: "mbl", transport_mode: "customer", created_by: user)).not_to be_valid
  end

  it "prevents reopening a manifest while its merchandise is reserved" do
    reserve(trip, instruction, item, 2)

    expect { item.cargo_manifest.reopen_by!(user) }.to raise_error(AASM::InvalidTransition)
    expect(item.cargo_manifest.reload).to be_confirmed
  end

  it "does not reserve unweighed grouped cargo for a weight instruction" do
    weight_instruction = request.instructions.create!(criterion: "weight", weight_kg: 100)

    expect { reserve(trip, weight_instruction, item, 1) }
      .to raise_error(described_class::Error, I18n.t("cargo_dispatch.errors.invalid_item"))
  end

  it "rolls back all reservations if any selection belongs to another client" do
    other_manifest = create(:cargo_manifest)
    other_item = create(:cargo_item, cargo_manifest: other_manifest, cargo_packaging: packaging, quantity: 2, weight_kg: nil)
    other_manifest.confirm_by!(user)
    other_item.store_at!(create(:warehouse_slot), "A", user)
    selections = [ item, other_item ].map { |line| { instruction_id: instruction.id, cargo_item_id: line.id, quantity: 1 } }

    expect { described_class.call(trip: trip, selections: selections) }
      .to raise_error(described_class::Error, I18n.t("cargo_dispatch.errors.invalid_item"))
    expect(trip.allocations).to be_empty
  end
end

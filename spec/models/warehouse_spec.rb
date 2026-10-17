require "rails_helper"

RSpec.describe "Warehouse locations", type: :model do
  describe WarehouseBay do
    it { is_expected.to have_many(:warehouse_slots).dependent(:restrict_with_error) }
    it { is_expected.to validate_numericality_of(:number).only_integer.is_in(1..4) }
  end

  describe WarehouseSlot do
    it { is_expected.to belong_to(:warehouse_bay) }
    it { is_expected.to have_many(:cargo_items).dependent(:restrict_with_error) }
    it { is_expected.to validate_numericality_of(:number).only_integer.is_in(1..16) }

    it "builds its code and QR token" do
      slot = create(:warehouse_slot, warehouse_bay: create(:warehouse_bay, number: 3), number: 7)

      expect(slot.code).to eq("N3-07")
      expect(slot.qr_token).to be_present
      expect(slot.to_param).to eq(slot.qr_token)
    end

    it "does not repeat a number within a bay" do
      bay = create(:warehouse_bay, number: 2)
      create(:warehouse_slot, warehouse_bay: bay, number: 1)

      expect(build(:warehouse_slot, warehouse_bay: bay, number: 1)).not_to be_valid
    end
  end

  describe WarehouseCatalog do
    it "creates 4 bays and 63 slots, skipping slot 8 in bay 1, and is repeatable" do
      2.times { described_class.new.call }

      expect(WarehouseBay.count).to eq(4)
      expect(WarehouseSlot.count).to eq(63)
      expect(WarehouseBay.find_by(number: 1).warehouse_slots.pluck(:number)).not_to include(8)
      expect(WarehouseBay.find_by(number: 2).warehouse_slots.count).to eq(16)
    end
  end

  describe CargoItem do
    let(:user) { create(:user, :montacargas) }
    let(:slot) { create(:warehouse_slot) }
    let(:other_slot) { create(:warehouse_slot, number: 12) }

    # Las líneas solo se crean en borrador; después se confirma la captura.
    def confirmed_item
      create(:cargo_item).tap do |line|
        line.cargo_manifest.update_columns(status: "confirmed", confirmed_at: Time.current)
        line.reload
      end
    end

    it "stores a line of a confirmed capture and records the movement" do
      item = confirmed_item
      item.store_at!(slot, "B", user)

      expect(item.reload).to be_stored
      expect(item).to have_attributes(warehouse_slot: slot, slot_section: "B")
      expect(item.movements.last).to have_attributes(from_slot: nil, to_slot: slot, to_section: "B", user: user)
    end

    it "relocates and keeps the previous location in the history" do
      item = confirmed_item
      item.store_at!(slot, "A", user)
      item.store_at!(other_slot, "C", user)

      expect(item.movements.order(:id).last).to have_attributes(from_slot: slot, from_section: "A", to_slot: other_slot, to_section: "C")
    end

    it "does not store lines of a draft capture" do
      draft_item = create(:cargo_item)

      expect { draft_item.store_at!(slot, "A", user) }.to raise_error(AASM::InvalidTransition)
      expect(draft_item.reload.warehouse_slot).to be_nil
    end

    it "rejects invalid sections and disabled slots" do
      stored = confirmed_item

      expect { stored.store_at!(slot, "D", user) }.to raise_error(ActiveRecord::RecordInvalid)
      slot.update!(enabled: false)
      expect { stored.store_at!(slot, "A", user) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "keeps recorded movements immutable" do
      stored = confirmed_item
      stored.store_at!(slot, "A", user)

      expect(stored.movements.last.update(to_section: "B")).to be false
    end
  end
end

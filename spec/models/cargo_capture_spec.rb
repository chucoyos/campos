require "rails_helper"

RSpec.describe "Cargo capture models", type: :model do
  describe CargoPackaging do
    it { is_expected.to have_many(:cargo_items).dependent(:restrict_with_error) }
  end

  describe CargoManifest do
    it { is_expected.to belong_to(:client) }
    it { is_expected.to belong_to(:container).optional }
    it { is_expected.to have_many(:cargo_items).dependent(:destroy) }

    it "requires a container to belong to the selected client's MBL" do
      manifest = build(:cargo_manifest, client: create(:client), container: create(:container, :with_master_bl))

      expect(manifest).not_to be_valid
      expect(manifest.errors[:container]).to be_present
    end
  end

  describe CargoItem do
    it { is_expected.to belong_to(:cargo_manifest) }
    it { is_expected.to belong_to(:cargo_packaging) }

    it "allows rolls without a source identifier or QR" do
      item = build(:cargo_item, origin_identifier: nil, qr_token: nil)

      expect(item).to be_valid
    end

    it "accepts an optional origin identifier for any packaging" do
      expect(build(:cargo_item, origin_identifier: "ID-123")).to be_valid
      box = create(:cargo_packaging, :box)
      expect(build(:cargo_item, cargo_packaging: box, quantity: 5, weight_kg: nil, origin_identifier: "ID-123")).to be_valid
    end

    it "requires weight for each pallet or roll" do
      item = build(:cargo_item, weight_kg: nil)

      expect(item).not_to be_valid
      expect(item.errors[:weight_kg]).to be_present
    end

    it "stores boxes as an aggregate quantity without per-box weight" do
      item = build(:cargo_item, cargo_packaging: build(:cargo_packaging, :box), quantity: 12, weight_kg: nil)

      expect(item).to be_valid
    end

    it "generates a QR token only when requested" do
      item = build(:cargo_item, generate_qr: true)

      expect(item).to be_valid
      expect(item.qr_token).to be_present
    end
  end
end

require "rails_helper"

RSpec.describe "Cargo capture models", type: :model do
  describe CargoManifestEvent do
    it { is_expected.to belong_to(:cargo_manifest) }
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to validate_inclusion_of(:event).in_array(%w[confirm reopen]) }

    it "is immutable once recorded" do
      user = create(:user, :admin)
      manifest = create(:cargo_manifest, :confirmed)
      manifest.reopen_by!(user)
      event = manifest.events.last

      expect(event.update(to_status: "confirmed")).to be false
    end
  end

  describe CargoPackaging do
    it { is_expected.to have_many(:cargo_items).dependent(:restrict_with_error) }
  end

  describe CargoManifest do
    describe "state machine" do
      let(:user) { create(:user, :admin) }
      let(:manifest) { create(:cargo_manifest) }

      it "starts as a draft and cannot be confirmed without items" do
        expect(manifest).to be_draft
        expect(manifest).not_to be_may_confirm
        expect { manifest.confirm_by!(user) }.to raise_error(AASM::InvalidTransition)
        expect(manifest.reload).to be_draft
      end

      it "confirms, stamps the date and records who did it" do
        create(:cargo_item, cargo_manifest: manifest)

        manifest.confirm_by!(user)

        expect(manifest.reload).to be_confirmed
        expect(manifest.confirmed_at).to be_present
        expect(manifest.events.last).to have_attributes(user: user, event: "confirm", from_status: "draft", to_status: "confirmed")
      end

      it "reopens only confirmed records, clears the date and records who did it" do
        expect { manifest.reopen_by!(user) }.to raise_error(AASM::InvalidTransition)

        confirmed = create(:cargo_manifest, :confirmed)
        confirmed.reopen_by!(user)

        expect(confirmed.reload).to be_draft
        expect(confirmed.confirmed_at).to be_nil
        expect(confirmed.events.last).to have_attributes(user: user, event: "reopen")
      end

      it "does not record an event when the transition is invalid" do
        expect { manifest.reopen_by!(user) }.to raise_error(AASM::InvalidTransition)
        expect(manifest.events).to be_empty
      end
    end

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

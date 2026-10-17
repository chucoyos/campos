require "rails_helper"

RSpec.describe CargoManifestPolicy do
  subject(:policy) { described_class.new(user, manifest) }

  let(:client) { create(:client) }
  let(:manifest) { create(:cargo_manifest, client: client) }

  context "as the owning client" do
    let(:user) { create(:user, :cliente, client: client) }

    it { is_expected.to permit_actions(%i[index show create update destroy confirm]) }
  end

  context "as another client" do
    let(:user) { create(:user, :cliente) }

    it do
      expect(policy.show?).to be false
      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
      expect(policy.confirm?).to be false
    end
  end

  context "as security staff" do
    let(:user) { create(:user, :seguridad) }

    it { is_expected.to permit_actions(%i[index show create update confirm]) }
    it { is_expected.to forbid_actions(%i[destroy]) }
  end

  context "when the record is confirmed" do
    let(:user) { create(:user, :admin) }
    let(:manifest) { create(:cargo_manifest, :confirmed) }

    it do
      expect(policy.update?).to be false
      expect(policy.destroy?).to be false
      expect(policy.confirm?).to be false
    end

    it { is_expected.to permit_actions(%i[reopen history]) }

    it "does not let other roles reopen" do
      expect(described_class.new(create(:user, :seguridad), manifest).history?).to be false
      expect(described_class.new(create(:user, :cliente, client: manifest.client), manifest).history?).to be false
      expect(described_class.new(create(:user, :seguridad), manifest).reopen?).to be false
      expect(described_class.new(create(:user, :cliente, client: manifest.client), manifest).reopen?).to be false
    end
  end
end

RSpec.describe WarehouseSlotPolicy do
  let(:slot) { create(:warehouse_slot) }

  it "lets operators view and only admin and forklift users store" do
    expect(described_class.new(create(:user, :seguridad), slot)).to permit_actions(%i[index show labels])
    expect(described_class.new(create(:user, :seguridad), slot).store?).to be false
    expect(described_class.new(create(:user, :montacargas), slot)).to permit_actions(%i[index show store labels])
    expect(described_class.new(create(:user, :cliente), slot).index?).to be false
  end
end

RSpec.describe CargoItemPolicy, "#store?" do
  it "requires a confirmed capture and an admin or forklift user" do
    item = create(:cargo_item)
    expect(described_class.new(create(:user, :montacargas), item).store?).to be false

    item.cargo_manifest.update_columns(status: "confirmed")
    expect(described_class.new(create(:user, :montacargas), item).store?).to be true
    expect(described_class.new(create(:user, :admin), item).store?).to be true
    expect(described_class.new(create(:user, :seguridad), item).store?).to be false
  end
end

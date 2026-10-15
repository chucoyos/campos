require "rails_helper"

RSpec.describe YardCatalog do
  it "creates the full catalog with 1384 positions, the CFS blocks having a single level" do
    described_class.new.call

    expect(YardBlock.pluck(:code)).to match_array(%w[1A 1B 1C 1CFS 2CFS 3CFS])
    expect(YardSlot.count).to eq(1384)
    expect(YardSlot.exists?(code: "1C20G5")).to be true
    expect(YardSlot.exists?(code: "3CFS4L1")).to be true
    expect(YardSlot.exists?(code: "3CFS4L2")).to be false
  end

  it "renames the former D blocks in place, keeping their positions and enabled state" do
    old_definition = [ { code: "1D", bays: 4, rows: 12, levels: 5 } ]
    described_class.new(blocks: old_definition, renames: {}).call
    old_slot = YardSlot.find_by!(code: "1D3A1")
    old_slot.update!(enabled: false)

    described_class.new.call

    expect(YardBlock.exists?(code: "1D")).to be false
    expect(old_slot.reload.code).to eq("1CFS3A1")
    expect(old_slot).not_to be_enabled
    expect(YardBlock.find_by!(code: "1CFS").yard_slots.count).to eq(48)
  end

  it "is repeatable and keeps the enabled state of existing positions" do
    described_class.new.call
    YardSlot.find_by!(code: "1A1A1").update!(enabled: false)

    expect { described_class.new.call }.not_to change { [ YardSlot.count, YardBlock.count ] }
    expect(YardSlot.find_by!(code: "1A1A1")).not_to be_enabled
  end

  it "adapts to changed definitions, removing obsolete positions and blocks" do
    described_class.new.call
    definition = [ { code: "1A", bays: 2, rows: 1, levels: 1 } ]
    result = described_class.new(blocks: definition).call

    expect(result.blocks.size).to eq(1)
    expect(YardSlot.pluck(:code)).to match_array(%w[1A1A1 1A2A1])
    expect(YardBlock.pluck(:code)).to eq(%w[1A])
  end

  it "does not touch other tables" do
    container = create(:container)
    user = create(:user)

    expect { described_class.new.call }.not_to change { [ Container.count, User.count, MasterBl.count, Client.count ] }
    expect(container.reload).to be_persisted
    expect(user.reload).to be_persisted
  end
end

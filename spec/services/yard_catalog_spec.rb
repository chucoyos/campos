require "rails_helper"

RSpec.describe YardCatalog do
  it "creates the full catalog with 1960 positions and DesyCon" do
    described_class.new.call

    expect(YardBlock.pluck(:code)).to match_array(%w[1A 1B 1C 1D 2D 3D])
    expect(YardSlot.count).to eq(1960)
    expect(YardSlot.exists?(code: "1C20G5")).to be true
    expect(YardSlot.exists?(code: "3D4L1")).to be true
    expect(YardArea.find_by!(code: "DESYCON").capacity).to eq(72)
  end

  it "is repeatable and keeps the enabled state of existing positions" do
    described_class.new.call
    YardSlot.find_by!(code: "1A1A1").update!(enabled: false)

    expect { described_class.new.call }.not_to change { [ YardSlot.count, YardBlock.count, YardArea.count ] }
    expect(YardSlot.find_by!(code: "1A1A1")).not_to be_enabled
  end

  it "adapts to changed definitions, removing obsolete positions, blocks and areas" do
    described_class.new.call
    definition = [ { code: "1A", bays: 2, rows: 1, levels: 1 } ]
    result = described_class.new(blocks: definition, areas: [ { code: "DESYCON", name: "DesyCon", capacity: 10 } ]).call

    expect(result.blocks.size).to eq(1)
    expect(YardSlot.pluck(:code)).to match_array(%w[1A1A1 1A2A1])
    expect(YardBlock.pluck(:code)).to eq(%w[1A])
    expect(YardArea.find_by!(code: "DESYCON").capacity).to eq(10)
  end

  it "does not touch other tables" do
    container = create(:container)
    user = create(:user)

    expect { described_class.new.call }.not_to change { [ Container.count, User.count, MasterBl.count, Client.count ] }
    expect(container.reload).to be_persisted
    expect(user.reload).to be_persisted
  end
end

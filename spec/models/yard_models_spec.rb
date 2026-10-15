require "rails_helper"

RSpec.describe YardBlock, type: :model do
  subject { build(:yard_block) }

  it { is_expected.to have_many(:yard_slots).dependent(:restrict_with_error) }
  it { is_expected.to validate_presence_of(:code) }
  it { is_expected.to validate_uniqueness_of(:code).ignoring_case_sensitivity }
  it { is_expected.to validate_numericality_of(:bays).only_integer.is_greater_than(0) }
  it { is_expected.to validate_numericality_of(:levels).only_integer.is_greater_than(0) }
  it { is_expected.to validate_numericality_of(:rows).only_integer.is_greater_than(0).is_less_than_or_equal_to(26) }
  it { is_expected.not_to allow_value("C1").for(:code) }
  it { is_expected.to allow_value("1c").for(:code) }

  it "lists row letters and counts 20 ft slots" do
    block = build(:yard_block, bays: 4, rows: 3, levels: 5)
    expect(block.row_letters).to eq(%w[A B C])
    expect(block.slots_count).to eq(60)
  end
end

RSpec.describe YardSlot, type: :model do
  let(:block) { create(:yard_block, code: "1C", bays: 10, rows: 7, levels: 5) }

  it { is_expected.to belong_to(:yard_block) }

  it "builds the code from block, bay, row and level" do
    expect(create(:yard_slot, yard_block: block, bay: 5, row: "B", level: 1).code).to eq("1C5B1")
  end

  it "rejects positions outside the block" do
    expect(build(:yard_slot, yard_block: block, bay: 11)).not_to be_valid
    expect(build(:yard_slot, yard_block: block, row: "H")).not_to be_valid
    expect(build(:yard_slot, yard_block: block, level: 6)).not_to be_valid
  end

  it "rejects duplicated positions" do
    create(:yard_slot, yard_block: block, bay: 2, row: "A", level: 1)
    expect(build(:yard_slot, yard_block: block, bay: 2, row: "A", level: 1)).not_to be_valid
  end

  it "anchors 40 ft containers on odd bays" do
    expect(build(:yard_slot, bay: 3)).to be_forty_foot_anchor
    expect(build(:yard_slot, bay: 4)).not_to be_forty_foot_anchor
  end

  it "is enabled by default" do
    expect(create(:yard_slot, yard_block: block)).to be_enabled
  end
end

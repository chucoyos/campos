require "rails_helper"

RSpec.describe YardArea, type: :model do
  subject { build(:yard_area) }

  it { is_expected.to belong_to(:yard_block) }
  it { is_expected.to belong_to(:client).optional }
  it { is_expected.to have_many(:sections).dependent(:restrict_with_error) }
  it { is_expected.to validate_presence_of(:code) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:code).ignoring_case_sensitivity }
end

RSpec.describe YardAreaSection, type: :model do
  subject { build(:yard_area_section) }

  it { is_expected.to belong_to(:yard_area) }
  it { is_expected.to belong_to(:master_bl).optional }
  it { is_expected.to have_many(:yard_slots).dependent(:nullify) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:yard_area_id) }

  it "solo acepta MBL del cliente del área" do
    area = create(:yard_area)
    expect(build(:yard_area_section, yard_area: area, master_bl: create(:master_bl, client: area.client))).to be_valid
    expect(build(:yard_area_section, yard_area: area, master_bl: create(:master_bl))).not_to be_valid
  end

  describe "#assign_slots" do
    let(:block) { create(:yard_block, code: "1C", bays: 4, rows: 2, levels: 1) }
    let(:area) { create(:yard_area, yard_block: block) }
    let(:first) { create(:yard_area_section, yard_area: area) }
    let(:second) { create(:yard_area_section, yard_area: area) }

    before { block.row_letters.product((1..4).to_a).each { |row, bay| create(:yard_slot, yard_block: block, bay: bay, row: row, level: 1) } }

    it "asigna posiciones y no quita las de otra sección activa" do
      expect(first.assign_slots(bays: [ 1, 2 ], rows: %w[A], levels: [ 1 ])).to eq(assigned: 2, conflicts: 0)
      expect(second.assign_slots(bays: [ 2, 3 ], rows: %w[A], levels: [ 1 ])).to eq(assigned: 1, conflicts: 1)
      expect(first.yard_slots.count).to eq(2)
    end

    it "permite reasignar posiciones de una sección inactiva" do
      first.assign_slots(bays: [ 1 ], rows: %w[A], levels: [ 1 ])
      first.update!(active: false)
      expect(second.assign_slots(bays: [ 1 ], rows: %w[A], levels: [ 1 ])[:assigned]).to eq(1)
    end

    it "libera posiciones" do
      first.assign_slots(bays: [ 1, 2 ], rows: %w[A], levels: [ 1 ])
      expect(first.release_slots(bays: [ 1 ], rows: %w[A], levels: [ 1 ])).to eq(1)
      expect(first.yard_slots.count).to eq(1)
    end
  end
end

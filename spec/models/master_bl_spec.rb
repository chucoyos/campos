require "rails_helper"

RSpec.describe MasterBl, type: :model do
  subject { build(:master_bl) }

  it { is_expected.to belong_to(:client) }
  it { is_expected.to have_many(:containers).dependent(:restrict_with_error) }
  it { is_expected.to validate_presence_of(:number) }
  it { is_expected.to validate_uniqueness_of(:number).ignoring_case_sensitivity }

  it "normalizes the number" do
    expect(build(:master_bl, number: "  cosu123 ").number).to eq("COSU123")
  end

  it "prevents deleting a client that has master BLs" do
    master_bl = create(:master_bl)
    expect(master_bl.client.destroy).to be(false)
  end
end

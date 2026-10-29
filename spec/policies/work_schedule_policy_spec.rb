require "rails_helper"

RSpec.describe WorkSchedulePolicy do
  let(:schedule) { build(:work_schedule) }

  it "solo permite administrar programaciones al administrador" do
    expect(described_class.new(create(:user, :admin), schedule)).to be_index
    expect(described_class.new(create(:user, :admin), schedule)).to be_create
    expect(described_class.new(create(:user, :grua), schedule)).not_to be_index
    expect(described_class.new(create(:user, :grua), schedule)).not_to be_create
  end

  it "solo cancela programaciones activas" do
    admin = create(:user, :admin)
    expect(described_class.new(admin, schedule)).to be_cancel
    expect(described_class.new(admin, build(:work_schedule, status: "cancelada"))).not_to be_cancel
  end
end

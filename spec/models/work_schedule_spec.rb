require "rails_helper"

RSpec.describe WorkSchedule, type: :model do
  subject(:schedule) { build(:work_schedule) }

  it { is_expected.to belong_to(:master_bl).optional }
  it { is_expected.to validate_presence_of(:scheduled_for) }
  it { is_expected.to have_many(:work_orders) }
  it { is_expected.to have_many(:movement_plans) }

  it "completa y cancela mediante AASM" do
    schedule.save!
    schedule.completar!
    expect(schedule).to be_completada
    expect { schedule.cancelar! }.to raise_error(AASM::InvalidTransition)

    canceled = create(:work_schedule)
    canceled.cancelar!
    expect(canceled).to be_cancelada
  end
end

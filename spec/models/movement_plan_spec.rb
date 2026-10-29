require "rails_helper"

RSpec.describe MovementPlan, type: :model do
  subject(:plan) { build(:movement_plan) }

  it { is_expected.to belong_to(:container) }
  it { is_expected.to belong_to(:movement_pass).optional }
  it { is_expected.to have_many(:work_orders) }

  it "solo permite reacomodo independiente con destino final" do
    plan.destination_yard_slot = nil

    expect(plan).not_to be_valid
  end

  it "permite finalizar un plan sin origen ya no pendiente" do
    plan.assign_attributes(status: "completada", origin_yard_slot: nil)

    expect(plan).to be_valid
  end

  it "completa y cancela el plan mediante AASM" do
    plan.save!
    plan.completar!
    expect(plan).to be_completada

    canceled = create(:movement_plan)
    canceled.cancelar!
    expect(canceled).to be_cancelada
  end
end

require "rails_helper"

RSpec.describe MovementPlanService do
  let(:user) { create(:user, :grua) }
  let(:block) { create(:yard_block, bays: 6, rows: 1, levels: 2) }
  let!(:base_slot) { create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 1) }
  let!(:top_slot) { create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 2) }
  let!(:blocker_destination) { create(:yard_slot, yard_block: block, bay: 3, row: "A", level: 1) }
  let!(:final_destination) { create(:yard_slot, yard_block: block, bay: 5, row: "A", level: 1) }
  let!(:target) { create(:container, current_yard_slot: base_slot) }
  let!(:blocker) { create(:container, current_yard_slot: top_slot) }

  it "espera a que concluya la tarea pendiente del bloqueador y luego continúa" do
    blocker_order = create(:work_order, container: blocker, movement_type: "reacomodo", movement_pass: nil,
      from_yard_slot: top_slot, to_yard_slot: blocker_destination)

    plan = described_class.create_independent(container: target, user:, destination_id: final_destination.id)

    expect(plan).to be_a(MovementPlan)
    expect(plan.work_orders).to be_empty
    expect(blocker.work_orders.where(status: "pendiente").count).to eq(1)

    CraneTaskService.complete(work_order: blocker_order, user:)

    target_order = plan.reload.work_orders.find_by!(status: "pendiente")
    expect(target_order).to have_attributes(container: target, to_yard_slot: final_destination)
  end
end

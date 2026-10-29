require "rails_helper"

RSpec.describe WorkScheduleService do
  let(:admin) { create(:user, :admin) }
  let(:crane_user) { create(:user, :grua) }
  let(:master_bl) { create(:master_bl) }
  let(:yard) { create(:yard_block, bays: 6, rows: 1, levels: 2) }
  let!(:desycon) { create(:yard_block, code: "1CFS", bays: 4, rows: 2, levels: 1) }
  let!(:slot_a) { create(:yard_slot, yard_block: yard, bay: 1, row: "A", level: 1) }
  let!(:slot_b) { create(:yard_slot, yard_block: yard, bay: 3, row: "A", level: 1) }
  let!(:top_slot) { create(:yard_slot, yard_block: yard, bay: 1, row: "A", level: 2) }
  let!(:desycon_slots) { [ 1, 2 ].map { |bay| create(:yard_slot, yard_block: desycon, bay:, row: "A", level: 1) } }

  def schedule_for(*containers)
    described_class.create(container_ids: containers.map(&:id), scheduled_for: Date.current, user: admin, master_bl:)
  end

  it "crea una tarea de reacomodo a DESYCON por cada contenedor libre" do
    first = create(:container, master_bl:, current_yard_slot: slot_a)
    second = create(:container, master_bl:, current_yard_slot: slot_b)

    schedule = schedule_for(first, second)

    orders = schedule.work_orders.order(:container_id)
    expect(orders.map(&:movement_type)).to all(eq("reacomodo"))
    expect(orders.map(&:to_yard_slot)).to match_array(desycon_slots)
    expect(orders.map(&:to_yard_slot).map(&:desycon?)).to all(be(true))
  end

  it "usa un plan agrupado cuando el contenedor está bloqueado" do
    target = create(:container, master_bl:, current_yard_slot: slot_a)
    blocker = create(:container, current_yard_slot: top_slot)

    schedule = schedule_for(target)

    plan = schedule.movement_plans.sole
    expect(plan).to have_attributes(container: target, work_schedule: schedule)
    blocker_order = plan.work_orders.sole
    expect(blocker_order.container).to eq(blocker)
    expect(blocker_order.to_yard_slot).not_to be_desycon
  end

  it "cierra la programación al mover el último contenedor y libera la posición" do
    container = create(:container, master_bl:, current_yard_slot: slot_a)
    schedule = schedule_for(container)

    CraneTaskService.complete(work_order: schedule.work_orders.sole, user: crane_user)

    expect(container.reload.current_yard_slot).to be_desycon
    expect(schedule.reload).to be_completada
    expect(GateMovementService.available_slots(create(:container)).map(&:id)).to include(slot_a.id)
  end

  it "rechaza confirmar un destino fuera de DESYCON" do
    container = create(:container, master_bl:, current_yard_slot: slot_a)
    order = schedule_for(container).work_orders.sole

    expect { CraneTaskService.complete(work_order: order, user: crane_user, yard_slot_id: slot_b.id) }
      .to raise_error(CraneTaskService::Error, /DESYCON/)
  end

  it "rechaza contenedores con tarea pendiente o sin espacio y no deja datos parciales" do
    busy = create(:container, master_bl:, current_yard_slot: slot_a)
    create(:work_order, container: busy, movement_type: "reacomodo", from_yard_slot: slot_a, to_yard_slot: slot_b, movement_pass: nil)

    expect { schedule_for(busy) }.to raise_error(WorkScheduleService::Error, /tarea o plan pendiente/)
    expect(WorkSchedule.count).to eq(0)

    desycon_slots.each { |slot| create(:container, current_yard_slot: slot) }
    other = create(:container, master_bl:, current_yard_slot: slot_b)
    expect { schedule_for(other) }.to raise_error(WorkScheduleService::Error, /DESYCON/)
  end

  it "cancela las tareas y planes pendientes" do
    target = create(:container, master_bl:, current_yard_slot: slot_a)
    create(:container, current_yard_slot: top_slot)
    schedule = schedule_for(target)

    described_class.cancel(schedule:, user: admin)

    expect(schedule.reload).to be_cancelada
    expect(WorkOrder.where(status: "pendiente")).to be_empty
    expect(MovementPlan.where(status: "pendiente")).to be_empty
  end
end

require "rails_helper"

RSpec.describe RehandlingRequestService do
  let(:security_user) { create(:user, :seguridad) }
  let(:crane_user) { create(:user, :grua) }
  let(:block) { create(:yard_block, bays: 6, rows: 1, levels: 3) }
  let!(:base_slot) { create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 1) }
  let!(:blocker_slot) { create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 2) }
  let!(:free_slot) { create(:yard_slot, yard_block: block, bay: 3, row: "A", level: 1) }
  let!(:second_free_slot) { create(:yard_slot, yard_block: block, bay: 4, row: "A", level: 1) }
  let(:target) { create(:container, current_yard_slot: base_slot) }
  let(:blocker) { create(:container, current_yard_slot: blocker_slot) }
  let(:pass) { create(:movement_pass, :standalone, container: target, movement_type: "salida", load_status: nil) }

  it "crea solicitud al entrar el camión, mueve bloqueadores de arriba hacia abajo y carga el objetivo" do
    blocker
    top_slot = create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 3)
    top_container = create(:container, current_yard_slot: top_slot)
    GateMovementService.call(pass:, user: security_user)

    request = RehandlingRequest.find_by!(movement_pass: pass)
    first_order = request.work_orders.find_by!(status: "pendiente")
    expect(first_order).to have_attributes(container: top_container, movement_type: "reacomodo", from_yard_slot: top_slot)
    expect(first_order.to_yard_slot).to eq(free_slot)
    expect(pass.reload).to have_attributes(status: "vigente")
    expect(pass.entered_at).to be_present

    CraneTaskService.complete(work_order: first_order, user: crane_user)
    second_order = request.work_orders.find_by!(status: "pendiente")
    expect(second_order).to have_attributes(container: blocker, movement_type: "reacomodo", from_yard_slot: blocker_slot)
    expect(GateMovementService.available_slots(blocker, except_work_order_id: second_order.id))
      .to include(second_order.to_yard_slot)
    expect(second_order.to_yard_slot).not_to eq(blocker_slot)

    CraneTaskService.complete(work_order: second_order, user: crane_user)
    load_order = WorkOrder.find_by!(movement_pass: pass, status: "pendiente")
    expect(load_order).to have_attributes(movement_type: "salida", container: target, rehandling_request: request)

    CraneTaskService.complete(work_order: load_order, user: crane_user)
    expect(request.reload).to be_completada
    expect(target.reload.current_yard_slot).to be_nil
    expect(ContainerMovement.order(:id).pluck(:movement_type)).to eq(%w[reacomodo reacomodo salida])

    pass.update!(exit_scanned_at: Time.current)
    GateMovementService.call(pass:, user: security_user)
    expect(pass.reload).to be_completado
  end

  it "deja el pase de salida abierto y no registra carga si hay bloqueadores" do
    blocker

    expect {
      GateMovementService.call(pass:, user: security_user)
    }.not_to change(ContainerMovement, :count)

    expect(pass.reload).to be_vigente
    expect(WorkOrder.where(movement_pass: pass)).to be_empty
    expect(RehandlingRequest.where(movement_pass: pass)).to exist
  end

  it "reintenta la planificación cuando vuelve a haber un destino disponible" do
    blocker
    free_slot.update!(enabled: false)
    second_free_slot.update!(enabled: false)
    GateMovementService.call(pass:, user: security_user)
    request = RehandlingRequest.find_by!(movement_pass: pass)
    expect(request.work_orders).to be_empty

    free_slot.update!(enabled: true)
    described_class.advance_pending

    expect(request.work_orders.pendiente.first).to have_attributes(
      container: blocker, to_yard_slot: free_slot, movement_type: "reacomodo"
    )
  end

  it "permite reacomodo independiente con destino válido y no cambia el estado de carga" do
    source = create(:yard_slot, yard_block: block, bay: 5, row: "A", level: 1)
    container = create(:container, :with_master_bl, current_yard_slot: source, status: "vacio")
    container.llenar!
    container.vaciar!

    order = described_class.create_independent(container:, user: crane_user, destination_id: free_slot.id)
    CraneTaskService.complete(work_order: order, user: crane_user)

    expect(container.reload).to have_attributes(current_yard_slot: free_slot, status: "vacio")
    expect(ContainerMovement.last).to have_attributes(
      movement_type: "reacomodo", movement_pass: nil, from_yard_slot: source, to_yard_slot: free_slot
    )
  end

  it "cancelar solicitud no revierte reacomodos previos y permite cerrar el pase con el camión vacío" do
    blocker
    GateMovementService.call(pass:, user: security_user)
    request = RehandlingRequest.find_by!(movement_pass: pass)

    described_class.cancel(request:, user: create(:user, :admin))

    expect(request.reload).to be_cancelada
    expect(pass.reload).to be_vigente
    pass.update!(exit_scanned_at: Time.current)
    GateMovementService.call(pass:, user: security_user)
    expect(pass.reload).to be_completado
  end
end

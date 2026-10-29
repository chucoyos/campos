require "rails_helper"

RSpec.describe CraneTaskService do
  let(:crane_user) { create(:user, :grua) }
  let(:security_user) { create(:user, :seguridad) }
  let(:block) { create(:yard_block, bays: 4, rows: 1, levels: 2) }
  let!(:slot) { create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 1) }
  let(:container) { create(:container) }
  let(:pass) { create(:movement_pass, :standalone, container: container) }

  def queue_entry(entry_pass = pass, yard_slot = slot)
    GateMovementService.call(pass: entry_pass, user: security_user, yard_slot_id: yard_slot.id)
    WorkOrder.find_by!(movement_pass: entry_pass)
  end

  it "coloca el contenedor, registra el movimiento y cierra la tarea" do
    order = queue_entry

    expect { described_class.complete(work_order: order, user: crane_user) }
      .to change(ContainerMovement, :count).by(1)

    expect(order.reload).to be_completada
    expect(order).to have_attributes(completed_by: crane_user)
    expect(order.completed_at).to be_present
    expect(container.reload).to have_attributes(current_yard_slot: slot, status: "lleno")
    expect(ContainerMovement.last).to have_attributes(
      container: container, movement_pass: pass, to_yard_slot: slot, user: crane_user, movement_type: "ingreso"
    )
  end

  it "no permite concluir dos veces" do
    order = queue_entry
    described_class.complete(work_order: order, user: crane_user)

    expect { described_class.complete(work_order: order, user: crane_user) }
      .to raise_error(CraneTaskService::Error, I18n.t("crane.errors.not_pending"))
  end

  it "rechaza el destino si dejó de estar habilitado" do
    order = queue_entry
    slot.update!(enabled: false)

    expect { described_class.complete(work_order: order, user: crane_user) }
      .to raise_error(CraneTaskService::Error, I18n.t("crane.errors.destination_unavailable"))
    expect(order.reload).to be_pendiente
    expect(container.reload.current_yard_slot).to be_nil
  end

  it "rechaza el destino si quedó ocupado físicamente" do
    order = queue_entry
    other = create(:container)
    other.update_columns(current_yard_slot_id: slot.id)

    expect { described_class.complete(work_order: order, user: crane_user) }
      .to raise_error(CraneTaskService::Error, I18n.t("crane.errors.destination_occupied"))
  end

  it "una orden cancelada libera la posición reservada" do
    order = queue_entry
    order.cancelar!
    other = create(:container)

    expect(GateMovementService.available_slots(other)).to include(slot)
  end

  it "bloquea la salida de un contenedor bajo una posición reservada" do
    upper = create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 2)
    base = create(:container)
    base_pass = create(:movement_pass, :standalone, container: base)
    described_class.complete(work_order: queue_entry(base_pass, slot), user: crane_user)
    top_pass = create(:movement_pass, :standalone, container: container)
    queue_entry(top_pass, upper)

    expect(GateMovementService.supporting_other?(base.reload)).to be(true)
  end
end

require "rails_helper"

RSpec.describe GateMovementService do
  let(:security_user) { create(:user, :seguridad) }
  let(:client) { create(:client) }
  let(:container) { create(:container, client: client) }
  let(:block) { create(:yard_block, bays: 4, rows: 1, levels: 2) }
  let(:slot) { create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 1) }
  let(:pass) { create(:movement_pass, :standalone, container: container) }
  let(:crane_user) { create(:user, :grua) }

  def enter(entry_pass, yard_slot)
    described_class.call(pass: entry_pass, user: security_user, yard_slot_id: yard_slot.id)
    CraneTaskService.complete(work_order: WorkOrder.find_by!(movement_pass: entry_pass), user: crane_user)
  end

  def exit_container(exit_pass)
    described_class.call(pass: exit_pass, user: security_user)
    order = WorkOrder.find_by!(movement_pass: exit_pass)
    CraneTaskService.complete(work_order: order, user: crane_user)
    exit_pass.update!(exit_scanned_at: Time.current)
    described_class.call(pass: exit_pass, user: security_user)
  end

  describe ".call" do
    it "registra la entrada del camión, crea la tarea y mantiene el pase abierto" do
      expect {
        described_class.call(pass: pass, user: security_user, yard_slot_id: slot.id)
      }.to change(WorkOrder, :count).by(1)

      expect(ContainerMovement.count).to eq(0)

      expect(pass.reload).to be_vigente
      expect(pass.entered_at).to be_present
      expect(container.reload.current_yard_slot).to be_nil
      expect(WorkOrder.last).to have_attributes(
        container: container, movement_pass: pass, to_yard_slot: slot,
        movement_type: "ingreso", created_by: security_user
      )
      expect(WorkOrder.last).to be_pendiente
    end

    it "reserva la posición pendiente y no la ofrece ni la acepta de nuevo" do
      described_class.call(pass: pass, user: security_user, yard_slot_id: slot.id)
      other = create(:container, client: client)
      other_pass = create(:movement_pass, :standalone, container: other)

      expect(described_class.available_slots(other)).not_to include(slot)
      expect {
        described_class.call(pass: other_pass, user: security_user, yard_slot_id: slot.id)
      }.to raise_error(GateMovementService::Error, I18n.t("gate.errors.location_occupied"))
    end

    it "no cuenta una posición reservada como soporte para apilar" do
      upper = create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 2)
      described_class.call(pass: pass, user: security_user, yard_slot_id: slot.id)
      other = create(:container, client: client)

      expect(described_class.available_slots(other)).not_to include(upper)
    end

    it "bloquea otro movimiento mientras el contenedor espera a la grúa" do
      described_class.call(pass: pass, user: security_user, yard_slot_id: slot.id)
      another_pass = create(:movement_pass, :standalone, container: container, movement_type: "salida", load_status: nil)

      expect {
        described_class.call(pass: another_pass, user: security_user, yard_slot_id: slot.id)
      }.to raise_error(GateMovementService::Error, I18n.t("gate.errors.entry_pending"))
    end

    it "rechaza una posición ocupada sin consumir el pase" do
      occupant = create(:container, client: client)
      occupant_pass = create(:movement_pass, :standalone, container: occupant)
      enter(occupant_pass, slot)

      expect {
        described_class.call(pass: pass, user: security_user, yard_slot_id: slot.id)
      }.to raise_error(GateMovementService::Error, I18n.t("gate.errors.location_occupied"))

      expect(pass.reload).to be_vigente
      expect(container.reload.current_yard_slot).to be_nil
    end

    it "no permite apilar sin un contenedor en el nivel inferior ni lo ofrece como opción" do
      upper = create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 2)
      slot

      expect(described_class.available_slots(container)).not_to include(upper)
      expect {
        described_class.call(pass: pass, user: security_user, yard_slot_id: upper.id)
      }.to raise_error(GateMovementService::Error, I18n.t("gate.errors.location_unsupported"))
      expect(pass.reload).to be_vigente
    end

    it "permite apilar sobre un contenedor y bloquea la salida del que soporta" do
      upper = create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 2)
      create(:yard_slot, yard_block: block, bay: 3, row: "A", level: 1)
      base = create(:container, client: client)
      base_pass = create(:movement_pass, :standalone, container: base)
      enter(base_pass, slot)

      expect(described_class.available_slots(container)).to include(upper)
      enter(pass, upper)
      expect(container.reload.current_yard_slot).to eq(upper)

      exit_pass = create(:movement_pass, :standalone, container: base.reload, movement_type: "salida")
      described_class.call(pass: exit_pass, user: security_user)

      request = RehandlingRequest.find_by!(movement_pass: exit_pass)
      expect(request).to be_pendiente
      expect(exit_pass.reload).to be_vigente
      expect(exit_pass.entered_at).to be_present
      expect(WorkOrder.where(rehandling_request: request, movement_type: "reacomodo", status: "pendiente").count).to eq(1)
    end

    it "reserva las dos bahías de un contenedor de 40 pies" do
      forty_foot = create(:container, :with_master_bl, size: 40)
      forty_pass = create(:movement_pass, container_assignment: create(:container_assignment, container: forty_foot))
      companion = create(:yard_slot, yard_block: block, bay: 2, row: "A", level: 1)

      enter(forty_pass, slot)

      other = create(:container, client: client)
      other_pass = create(:movement_pass, :standalone, container: other)
      expect {
        described_class.call(pass: other_pass, user: security_user, yard_slot_id: companion.id)
      }.to raise_error(GateMovementService::Error, I18n.t("gate.errors.location_occupied"))
    end

    it "requires a valid active pass and a location for entry" do
      expect {
        described_class.call(pass: pass, user: security_user)
      }.to raise_error(GateMovementService::Error, I18n.t("gate.errors.location_required"))

      pass.update_columns(expires_at: 1.minute.ago)
      expect {
        described_class.call(pass: pass, user: security_user, yard_slot_id: slot.id)
      }.to raise_error(GateMovementService::Error, I18n.t("gate.errors.pass_unusable"))
      expect(pass.reload).to be_vigente
    end

    it "cambia automáticamente el estatus de un contenedor con MBL: lleno al ingresar y entregado al salir vacío" do
      mbl_container = create(:container, :with_master_bl)
      entry_pass = create(:movement_pass, container_assignment: create(:container_assignment, container: mbl_container))
      expect(mbl_container.status).to eq("activo")

      enter(entry_pass, slot)
      expect(mbl_container.reload.status).to eq("lleno")

      mbl_container.vaciar!
      exit_pass = create(:movement_pass, container_assignment: create(:container_assignment, container: mbl_container, operation: "salida"), movement_type: "salida")
      exit_container(exit_pass)
      expect(mbl_container.reload.status).to eq("entregado")
    end

    it "registra la salida y libera la posición en patio" do
      container.update!(current_yard_slot: slot)
      exit_pass = create(:movement_pass, :standalone, container: container, movement_type: "salida", load_status: nil)

      exit_container(exit_pass)

      expect(container.reload.current_yard_slot).to be_nil
      expect(exit_pass.reload).to be_completado
      expect(ContainerMovement.last).to have_attributes(
        movement_type: "salida",
        from_yard_slot: slot,
        to_yard_slot: nil
      )
    end

    it "registra traspaleo con tarea de grúa sin ocupar patio" do
      transfer_pass = create(:movement_pass, :standalone, container: container, movement_type: "traspaleo")

      described_class.call(pass: transfer_pass, user: security_user)

      order = WorkOrder.find_by!(movement_pass: transfer_pass)
      expect(order).to be_pendiente.and be_traspaleo
      expect(ContainerMovement.where(movement_pass: transfer_pass)).to be_empty
      expect(transfer_pass.reload).to be_vigente

      CraneTaskService.complete(work_order: order, user: crane_user)

      expect(container.reload.current_yard_slot).to be_nil
      expect(transfer_pass.reload).to be_completado
      expect(ContainerMovement.last).to have_attributes(
        movement_type: "traspaleo",
        from_yard_slot: nil,
        to_yard_slot: nil
      )
    end

    it "rechaza completar dos veces el mismo pase" do
      described_class.call(pass: pass, user: security_user, yard_slot_id: slot.id)

      expect {
        described_class.call(pass: pass, user: security_user, yard_slot_id: slot.id)
      }.to raise_error(GateMovementService::Error, I18n.t("gate.errors.exit_scan_required"))
    end
  end

  describe ".available_slots" do
    it "sugiere primero la sección preasignada al contenedor" do
      preferred = create(:yard_slot, yard_block: block, bay: 3, row: "A", level: 1)
      mbl_container = create(:container, :with_master_bl)
      area = create(:yard_area, yard_block: block, client: mbl_container.master_bl.client)
      section = create(:yard_area_section, yard_area: area, master_bl: mbl_container.master_bl)
      preferred.update!(yard_area_section: section)
      assignment = create(:container_assignment, container: mbl_container, yard_area: area, yard_area_section: section)
      assigned_pass = create(:movement_pass, container_assignment: assignment)

      expect(described_class.suggested_slot(assigned_pass)).to eq(preferred)
    end
  end

  it "no permite modificar ni eliminar el historial" do
    enter(pass, slot)
    movement = ContainerMovement.last

    expect { movement.update!(created_at: 1.day.ago) }.to raise_error(ActiveRecord::RecordNotSaved)
    expect { movement.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
  end
end

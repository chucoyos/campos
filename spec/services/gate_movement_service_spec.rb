require "rails_helper"

RSpec.describe GateMovementService do
  let(:security_user) { create(:user, :seguridad) }
  let(:client) { create(:client) }
  let(:container) { create(:container, client: client) }
  let(:block) { create(:yard_block, bays: 4, rows: 1, levels: 2) }
  let(:slot) { create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 1) }
  let(:pass) { create(:movement_pass, :standalone, container: container) }

  describe ".call" do
    it "registra el ingreso, actualiza la ubicación y consume el pase en una transacción" do
      expect {
        described_class.call(pass: pass, user: security_user, yard_slot_id: slot.id)
      }.to change(ContainerMovement, :count).by(1)

      expect(pass.reload).to be_completado
      expect(container.reload.current_yard_slot).to eq(slot)
      expect(container.status).to eq("lleno")
      expect(ContainerMovement.last).to have_attributes(
        container: container,
        movement_pass: pass,
        from_yard_slot: nil,
        to_yard_slot: slot,
        user: security_user,
        movement_type: "ingreso"
      )
    end

    it "rechaza una posición ocupada sin consumir el pase" do
      occupant = create(:container, client: client)
      occupant_pass = create(:movement_pass, :standalone, container: occupant)
      described_class.call(pass: occupant_pass, user: security_user, yard_slot_id: slot.id)

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
      base = create(:container, client: client)
      base_pass = create(:movement_pass, :standalone, container: base)
      described_class.call(pass: base_pass, user: security_user, yard_slot_id: slot.id)

      expect(described_class.available_slots(container)).to include(upper)
      described_class.call(pass: pass, user: security_user, yard_slot_id: upper.id)
      expect(container.reload.current_yard_slot).to eq(upper)

      exit_pass = create(:movement_pass, :standalone, container: base.reload, movement_type: "salida")
      expect {
        described_class.call(pass: exit_pass, user: security_user)
      }.to raise_error(GateMovementService::Error, I18n.t("gate.errors.supports_other_container"))
    end

    it "reserva las dos bahías de un contenedor de 40 pies" do
      forty_foot = create(:container, :with_master_bl, size: 40)
      forty_pass = create(:movement_pass, container_assignment: create(:container_assignment, container: forty_foot))
      companion = create(:yard_slot, yard_block: block, bay: 2, row: "A", level: 1)

      described_class.call(pass: forty_pass, user: security_user, yard_slot_id: slot.id)

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

      described_class.call(pass: entry_pass, user: security_user, yard_slot_id: slot.id)
      expect(mbl_container.reload.status).to eq("lleno")

      mbl_container.vaciar!
      exit_pass = create(:movement_pass, container_assignment: create(:container_assignment, container: mbl_container, operation: "salida"), movement_type: "salida")
      described_class.call(pass: exit_pass, user: security_user)
      expect(mbl_container.reload.status).to eq("entregado")
    end

    it "registra la salida y libera la posición en patio" do
      container.update!(current_yard_slot: slot)
      exit_pass = create(:movement_pass, :standalone, container: container, movement_type: "salida", load_status: nil)

      described_class.call(pass: exit_pass, user: security_user)

      expect(container.reload.current_yard_slot).to be_nil
      expect(exit_pass.reload).to be_completado
      expect(ContainerMovement.last).to have_attributes(
        movement_type: "salida",
        from_yard_slot: slot,
        to_yard_slot: nil
      )
    end

    it "registra traspaleo sin ocupar patio" do
      transfer_pass = create(:movement_pass, :standalone, container: container, movement_type: "traspaleo")

      described_class.call(pass: transfer_pass, user: security_user)

      expect(container.reload.current_yard_slot).to be_nil
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
      }.to raise_error(GateMovementService::Error, I18n.t("gate.errors.pass_unusable"))
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
    described_class.call(pass: pass, user: security_user, yard_slot_id: slot.id)
    movement = ContainerMovement.last

    expect { movement.update!(created_at: 1.day.ago) }.to raise_error(ActiveRecord::RecordNotSaved)
    expect { movement.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
  end
end

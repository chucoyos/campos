require "rails_helper"

RSpec.describe DeconsolidationService do
  let(:admin) { create(:user, :admin) }
  let(:desycon) { create(:yard_block, code: "1CFS", bays: 4, rows: 2, levels: 1) }
  let(:yard) { create(:yard_block, bays: 4, rows: 1, levels: 1) }
  let!(:desycon_slot) { create(:yard_slot, yard_block: desycon, bay: 1, row: "A", level: 1) }
  let!(:free_slot) { create(:yard_slot, yard_block: yard, bay: 1, row: "A", level: 1) }
  let(:container) { create(:container, :with_master_bl, current_yard_slot: desycon_slot).tap(&:llenar!) }

  def attach_photo(section)
    container.public_send(:"#{section}_photos").attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
  end

  describe ".start" do
    it "crea la desconsolidación solo en DESYCON y una vez" do
      expect(described_class.start(container:, user: admin)).to be_apertura
      expect { described_class.start(container:, user: admin) }.to raise_error(described_class::Error)
    end

    it "rechaza contenedores fuera de DESYCON" do
      container.update!(current_yard_slot: free_slot)
      expect { described_class.start(container:, user: admin) }.to raise_error(described_class::Error)
    end
  end

  describe "avance completo" do
    let!(:deconsolidation) { described_class.start(container:, user: admin) }

    it "exige fotos, vacía el contenedor y crea el reacomodo para la grúa" do
      expect { described_class.advance(deconsolidation:, user: admin) }.to raise_error(described_class::Error, /apertura/)
      attach_photo("opening")
      described_class.advance(deconsolidation:, user: admin)
      expect(deconsolidation.reload).to be_desconsolidando

      expect { described_class.advance(deconsolidation:, user: admin) }.to raise_error(described_class::Error, /desconsolidaci/)
      attach_photo("deconsolidation")
      expect { expect(described_class.advance(deconsolidation:, user: admin).rehandle_order).to be_nil }.not_to change(WorkOrder, :count)
      expect(deconsolidation.reload).to be_vacio

      expect { described_class.advance(deconsolidation:, user: admin) }.to raise_error(described_class::Error, /vac/)
      attach_photo("empty")
      result = nil
      expect { result = described_class.advance(deconsolidation:, user: admin) }.to change(WorkOrder, :count).by(1)

      expect(deconsolidation.reload).to be_vaciado
      expect(container.reload).to be_vacio
      expect(result.rehandle_order).to have_attributes(movement_type: "reacomodo", from_yard_slot: desycon_slot, to_yard_slot: free_slot)
    end

    it "bloquea el vacío con mercancía sin ubicar" do
      manifest = create(:cargo_manifest, container:, client: container.master_bl.client)
      create(:cargo_item, cargo_manifest: manifest)
      manifest.update_columns(status: "confirmed", confirmed_at: Time.current)
      attach_photo("opening")
      described_class.advance(deconsolidation:, user: admin)
      attach_photo("deconsolidation")

      expect { described_class.advance(deconsolidation:, user: admin) }.to raise_error(described_class::Error, /mercanc/i)
    end
  end

  describe "destino sugerido del reacomodo" do
    let(:other_mbl) { create(:master_bl, client: container.master_bl.client) }
    let(:area) { create(:yard_area, yard_block: yard, client: container.master_bl.client) }

    def finish_deconsolidation
      deconsolidation = described_class.start(container:, user: admin)
      attach_photo("opening")
      described_class.advance(deconsolidation:, user: admin)
      attach_photo("deconsolidation")
      described_class.advance(deconsolidation:, user: admin)
      attach_photo("empty")
      described_class.advance(deconsolidation:, user: admin)
    end

    it "prefiere la sección del MBL del contenedor" do
      own = create(:yard_area_section, yard_area: area, master_bl: container.master_bl)
      free_slot.update!(yard_area_section: own)

      expect(finish_deconsolidation.rehandle_order.to_yard_slot).to eq(free_slot)
    end

    it "no sugiere secciones de otro MBL ni áreas de otro cliente" do
      foreign = create(:yard_area_section, yard_area: area, master_bl: other_mbl)
      free_slot.update!(yard_area_section: foreign)

      expect(finish_deconsolidation.rehandle_order).to be_nil
    end

    it "limita el destino de la grúa al área/sección del MBL y lo valida al completar" do
      own = create(:yard_area_section, yard_area: area, master_bl: container.master_bl)
      free_slot.update!(yard_area_section: own)
      foreign_slot = create(:yard_slot, yard_block: yard, bay: 3, row: "A", level: 1,
                            yard_area_section: create(:yard_area_section, yard_area: area, master_bl: other_mbl))

      order = finish_deconsolidation.rehandle_order
      expect(order.to_yard_slot).to eq(free_slot)

      sign_in_crane = create(:user, :grua)
      expect { CraneTaskService.complete(work_order: order, user: sign_in_crane, yard_slot_id: foreign_slot.id) }
        .to raise_error(CraneTaskService::Error, /área o sección/)
      expect { CraneTaskService.complete(work_order: order, user: sign_in_crane, yard_slot_id: free_slot.id) }
        .to change { container.reload.current_yard_slot }.to(free_slot)
    end

    it "no sugiere áreas de otro cliente" do
      other_area = create(:yard_area, yard_block: yard)
      free_slot.update!(yard_area_section: create(:yard_area_section, yard_area: other_area))

      expect(finish_deconsolidation.rehandle_order).to be_nil
    end
  end

  it "excluye DESYCON y ubicaciones de otros clientes/MBL de los destinos, salvo en programación" do
    other_area = create(:yard_area, yard_block: yard)
    foreign = create(:yard_slot, yard_block: yard, bay: 4, row: "A", level: 1,
                     yard_area_section: create(:yard_area_section, yard_area: other_area))
    container.update!(current_yard_slot: free_slot)

    expect(GateMovementService.available_slots(container)).not_to include(desycon_slot, foreign)
    expect(GateMovementService.available_slots(container, desycon: true)).to all(satisfy(&:desycon?))
  end

  it "acota los destinos al área/sección de la asignación de ingreso" do
    area = create(:yard_area, yard_block: yard, client: container.master_bl.client)
    chosen = create(:yard_area_section, yard_area: area, master_bl: container.master_bl)
    in_section = create(:yard_slot, yard_block: yard, bay: 2, row: "A", level: 1, yard_area_section: chosen)
    sibling = create(:yard_area_section, yard_area: area, master_bl: container.master_bl)
    outside = create(:yard_slot, yard_block: yard, bay: 3, row: "A", level: 1, yard_area_section: sibling)
    create(:container_assignment, container:, carrier: create(:carrier), operation: "ingreso", yard_area_section: chosen)

    slots = GateMovementService.available_slots(container)
    expect(slots).to include(in_section)
    expect(slots).not_to include(outside)
  end

  it "inicia automáticamente cuando la grúa deja el contenedor en DESYCON" do
    origin = free_slot
    container.update!(current_yard_slot: origin)
    order = create(:work_order, container:, movement_type: "reacomodo", from_yard_slot: origin, to_yard_slot: desycon_slot, movement_pass: nil,
                                  work_schedule: create(:work_schedule))

    expect { CraneTaskService.complete(work_order: order, user: create(:user, :grua)) }.to change(Deconsolidation, :count).by(1)
  end
end

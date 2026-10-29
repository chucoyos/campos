require "rails_helper"

RSpec.describe WorkOrder, type: :model do
  subject(:work_order) { create(:work_order) }

  it { is_expected.to belong_to(:container) }
  it { is_expected.to define_enum_for(:movement_type).with_values(ContainerMovement::TYPES.index_with(&:itself)).backed_by_column_of_type(:string) }

  it "requiere un destino para el ingreso" do
    order = build(:work_order, to_yard_slot: nil)
    expect(order).not_to be_valid
  end

  it "permite reacomodos sin pase de movimiento" do
    order = build(:work_order, movement_type: "reacomodo", movement_pass: nil, from_yard_slot: create(:yard_slot))

    expect(order).to be_valid
  end

  it "no admite dos tareas pendientes para el mismo contenedor" do
    duplicate = build(:work_order, container: work_order.container)
    expect(duplicate).not_to be_valid
  end

  describe "AASM" do
    it "inicia pendiente y puede completarse o cancelarse" do
      expect(work_order).to be_pendiente
      work_order.completar!
      expect(work_order).to be_completada
    end

    it "permite cancelar una tarea pendiente" do
      work_order.cancelar!
      expect(work_order).to be_cancelada
    end

    it "no permite transiciones desde un estado final" do
      work_order.completar!
      expect { work_order.cancelar! }.to raise_error(AASM::InvalidTransition)
      expect { work_order.completar! }.to raise_error(AASM::InvalidTransition)
    end
  end

  it "avisa a la grúa al crear y al concluir" do
    expect(Turbo::StreamsChannel).to receive(:broadcast_refresh_to).with(WorkOrder::STREAM).twice
    order = create(:work_order)
    order.completar!
  end
end

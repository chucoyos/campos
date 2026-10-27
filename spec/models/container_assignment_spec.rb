require "rails_helper"

RSpec.describe ContainerAssignment, type: :model do
  subject { build(:container_assignment) }

  it { is_expected.to belong_to(:container) }
  it { is_expected.to belong_to(:carrier) }
  it { is_expected.to belong_to(:assigned_by).class_name("User").optional }
  it { is_expected.to belong_to(:yard_area).optional }
  it { is_expected.to belong_to(:yard_area_section).optional }
  it { is_expected.to define_enum_for(:operation).with_values(ContainerAssignment::OPERATIONS.index_with(&:itself)).backed_by_column_of_type(:string) }
  it { is_expected.to validate_numericality_of(:preferred_level).only_integer.is_greater_than(0).allow_nil }

  it "exige que el contenedor pertenezca a un MBL" do
    assignment = build(:container_assignment, container: create(:container))
    expect(assignment).not_to be_valid
    expect(assignment.errors[:container]).to be_present
  end

  it "no permite dos asignaciones pendientes para el mismo contenedor y operación" do
    first = create(:container_assignment)
    expect(build(:container_assignment, container: first.container)).not_to be_valid
    expect(build(:container_assignment, container: first.container, operation: "salida")).to be_valid
  end

  it "permite reasignar tras cancelar" do
    first = create(:container_assignment)
    first.cancelar!
    expect(build(:container_assignment, container: first.container)).to be_valid
  end

  describe "área y sección" do
    let(:container) { create(:container, :with_master_bl) }
    let(:client) { container.master_bl.client }

    it "toma el área de la sección elegida" do
      section = create(:yard_area_section, yard_area: create(:yard_area, client: client))
      assignment = create(:container_assignment, container: container, yard_area_section: section)
      expect(assignment.yard_area).to eq(section.yard_area)
    end

    it "rechaza áreas de otro cliente o inactivas" do
      expect(build(:container_assignment, container: container, yard_area: create(:yard_area))).not_to be_valid
      expect(build(:container_assignment, container: container, yard_area: create(:yard_area, client: client, active: false))).not_to be_valid
    end

    it "rechaza una sección reservada a otro MBL" do
      area = create(:yard_area, client: client)
      section = create(:yard_area_section, yard_area: area, master_bl: create(:master_bl, client: client))
      expect(build(:container_assignment, container: container, yard_area_section: section)).not_to be_valid
    end

    it "rechaza una sección que no es del área" do
      area = create(:yard_area, client: client)
      expect(build(:container_assignment, container: container, yard_area: area, yard_area_section: create(:yard_area_section))).not_to be_valid
    end

    it "valida la estiba preferida contra los niveles del bloque" do
      area = create(:yard_area, client: client, yard_block: create(:yard_block, levels: 3))
      expect(build(:container_assignment, container: container, yard_area: area, preferred_level: 3)).to be_valid
      expect(build(:container_assignment, container: container, yard_area: area, preferred_level: 4)).not_to be_valid
    end
  end

  it "solo cambia de estado desde pendiente" do
    assignment = create(:container_assignment)
    assignment.utilizar!
    expect(assignment).to be_utilizada
    expect(assignment.may_cancelar?).to be(false)
  end

  it "no permite cancelar una asignación con un pase vigente" do
    assignment = create(:container_assignment)
    create(:movement_pass, container_assignment: assignment)

    expect(assignment).not_to be_may_cancelar
  end
end

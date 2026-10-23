require "rails_helper"

RSpec.describe ContainerAssignmentPolicy do
  let(:carrier) { create(:carrier) }
  let(:assignment) { create(:container_assignment, carrier: carrier) }
  let(:other) { create(:container_assignment) }

  it "deja administrar solo al admin" do
    admin = create(:user, :admin)
    expect(described_class.new(admin, assignment)).to be_create.and be_cancel
    expect(described_class.new(create(:user, :seguridad), assignment)).not_to be_create
  end

  it "limita al transporte a sus asignaciones" do
    user = create(:user, :transporte, carrier: carrier)
    assignment
    other
    expect(described_class::Scope.new(user, ContainerAssignment).resolve).to contain_exactly(assignment)
    expect(described_class.new(user, assignment)).not_to be_cancel
  end

  it "incluye a cuentas duales por su afiliación de transporte" do
    user = create(:user, :cliente, client: create(:client), carrier: carrier)
    expect(described_class.new(user, assignment)).to be_index
    expect(described_class::Scope.new(user, ContainerAssignment).resolve).to contain_exactly(assignment)
  end

  it "niega a clientes sin transporte y a invitados" do
    expect(described_class.new(create(:user, :cliente, client: create(:client)), assignment)).not_to be_index
    expect(described_class::Scope.new(nil, ContainerAssignment).resolve).to be_empty
  end
end

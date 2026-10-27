require "rails_helper"

RSpec.describe MovementPassPolicy do
  let(:carrier) { create(:carrier) }
  let(:client) { create(:client) }
  let(:assignment) { create(:container_assignment, carrier: carrier) }
  let(:mbl_pass) { create(:movement_pass, container_assignment: assignment) }
  let(:standalone_pass) { create(:movement_pass, :standalone, container: create(:container, client: client)) }

  def policy_for(user, record) = described_class.new(user, record)

  it "el admin lo administra todo y Seguridad solo consulta" do
    expect(policy_for(create(:user, :admin), mbl_pass)).to be_create.and be_cancel.and be_show.and be_gate
    seguridad = policy_for(create(:user, :seguridad), mbl_pass)
    expect(seguridad).to be_show.and be_index.and be_gate
    expect(seguridad).not_to be_create
  end

  it "solo permite usar Garita a admin y Seguridad" do
    expect(policy_for(create(:user, :transporte, carrier: carrier), MovementPass)).not_to be_gate
    expect(policy_for(create(:user, :cliente, client: client), MovementPass)).not_to be_gate
  end

  it "el transporte tramita solo asignaciones de su carrier" do
    user = create(:user, :transporte, carrier: carrier)
    expect(policy_for(user, mbl_pass)).to be_create.and be_show.and be_cancel
    other = create(:movement_pass)
    expect(policy_for(user, other)).not_to be_show
    expect(policy_for(user, build(:movement_pass, container_assignment: other.container_assignment))).not_to be_create
  end

  it "el cliente tramita solo sus contenedores de resguardo" do
    user = create(:user, :cliente, client: client)
    expect(policy_for(user, standalone_pass)).to be_create.and be_show.and be_cancel
    expect(policy_for(user, create(:movement_pass, :standalone))).not_to be_show
    expect(policy_for(user, build(:movement_pass, :standalone, container: create(:container, client: create(:client))))).not_to be_create
  end

  it "el cliente consulta pero no tramita pases de sus contenedores con MBL" do
    user = create(:user, :cliente, client: assignment.container.master_bl.client)
    expect(policy_for(user, mbl_pass)).to be_show
    expect(policy_for(user, mbl_pass)).not_to be_create
  end

  it "las cuentas duales usan ambas afiliaciones" do
    user = create(:user, :cliente, client: client, carrier: carrier)
    expect(policy_for(user, mbl_pass)).to be_create
    expect(policy_for(user, standalone_pass)).to be_create
  end

  it "no permite cancelar pases que ya no están vigentes" do
    standalone_pass.cancelar!
    expect(policy_for(create(:user, :admin), standalone_pass)).not_to be_cancel
  end

  describe "Scope" do
    it "limita el listado por afiliación" do
      mbl_pass
      standalone_pass
      other = create(:movement_pass)
      resolve = ->(user) { described_class::Scope.new(user, MovementPass).resolve }

      expect(resolve.call(create(:user, :admin))).to contain_exactly(mbl_pass, standalone_pass, other)
      expect(resolve.call(create(:user, :transporte, carrier: carrier))).to contain_exactly(mbl_pass)
      expect(resolve.call(create(:user, :cliente, client: client))).to contain_exactly(standalone_pass)
      expect(resolve.call(create(:user, :cliente, client: client, carrier: carrier))).to contain_exactly(mbl_pass, standalone_pass)
      expect(resolve.call(nil)).to be_empty
    end
  end
end

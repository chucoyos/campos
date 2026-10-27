require "rails_helper"

RSpec.describe MovementPass, type: :model do
  subject(:pass) { build(:movement_pass) }

  it { is_expected.to belong_to(:container) }
  it { is_expected.to belong_to(:carrier).optional }
  it { is_expected.to belong_to(:client).optional }
  it { is_expected.to belong_to(:requested_by).class_name("User").optional }
  it { is_expected.to have_many(:vehicles).class_name("MovementPassVehicle").dependent(:destroy) }
  it { is_expected.to define_enum_for(:movement_type).with_values(MovementPass::MOVEMENT_TYPES.index_with(&:itself)).backed_by_column_of_type(:string) }

  it "emite un token opaco único con vigencia de 48 horas" do
    pass.save!
    expect(pass.token).to be_present
    expect(pass.expires_at - pass.issued_at).to eq(48.hours)
    expect(pass.carrier_id).to eq(pass.container_assignment.carrier_id)
    expect(pass).to be_vigente
  end

  it "exige asignación para contenedores con MBL" do
    expect(build(:movement_pass, container_assignment: nil, container: create(:container, :with_master_bl))).not_to be_valid
  end

  it "no admite traspaleo con MBL" do
    assignment = create(:container_assignment)
    pass = build(:movement_pass, container_assignment: assignment, movement_type: "traspaleo")
    expect(pass).not_to be_valid
  end

  it "exige que la asignación coincida con la operación" do
    assignment = create(:container_assignment, operation: "salida")
    expect(build(:movement_pass, container_assignment: assignment, movement_type: "ingreso")).not_to be_valid
  end

  it "no permite dos pases vigentes del mismo contenedor y movimiento" do
    first = create(:movement_pass, :standalone)
    expect(build(:movement_pass, :standalone, container: first.container)).not_to be_valid
  end

  it "libera la emisión cuando el pase previo venció sin persistir" do
    first = create(:movement_pass, :standalone)
    first.update_columns(expires_at: 1.hour.ago)
    expect(build(:movement_pass, :standalone, container: first.container)).to be_valid
    expect(first.reload).to be_vencido
  end

  describe "resguardo" do
    it "exige el estado de carga declarado al ingresar" do
      expect(build(:movement_pass, :standalone, load_status: nil)).not_to be_valid
      expect(build(:movement_pass, :standalone, movement_type: "salida", load_status: nil)).to be_valid
    end

    it "toma el cliente propietario" do
      pass = create(:movement_pass, :standalone)
      expect(pass.client).to eq(pass.container.client)
    end

    it "no admite estado de carga con MBL" do
      expect(build(:movement_pass, load_status: "lleno")).not_to be_valid
    end
  end

  describe "vehículos" do
    it "exige datos del vehículo" do
      pass = build(:movement_pass)
      pass.vehicles.clear
      expect(pass).not_to be_valid
    end

    it "exige dos vehículos en un traspaleo" do
      pass = build(:movement_pass, :standalone, movement_type: "traspaleo")
      expect(pass.vehicles.map(&:role)).to match_array(%w[principal destino])
      expect(pass).to be_valid
      pass.vehicles = [ pass.vehicles.first ]
      expect(pass).not_to be_valid
    end

    it "normaliza las placas" do
      pass = create(:movement_pass)
      pass.vehicles.first.update!(plate: " ab-12 3 ")
      expect(pass.vehicles.first.plate).to eq("AB123")
    end
  end

  describe "estados" do
    it "completa una sola vez y utiliza la asignación" do
      pass = create(:movement_pass)
      pass.completar!
      expect(pass).to be_completado
      expect(pass.consumed_at).to be_present
      expect(pass.container_assignment).to be_utilizada
      expect(pass.may_completar?).to be(false)
    end

    it "no se puede completar vencido" do
      pass = create(:movement_pass)
      pass.update_columns(expires_at: 1.minute.ago)
      expect(pass.may_completar?).to be(false)
      expect(pass.display_status).to eq("vencido")
      expect { pass.vencer! }.to change { pass.reload.status }.to("vencido")
    end

    it "cancela solo si está vigente" do
      pass = create(:movement_pass, :standalone)
      pass.cancelar!
      expect(pass).to be_cancelado
      expect(pass.cancelled_at).to be_present
      expect(pass.may_cancelar?).to be(false)
      expect(pass.may_completar?).to be(false)
    end

    it "elimina la evidencia temporal al cancelar o vencer el pase" do
      photo = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("image"), filename: "evidencia.png", content_type: "image/png"
      )
      pass = create(:movement_pass, :standalone)
      pass.photos.attach(photo)

      pass.cancelar!

      expect(pass.photos).not_to be_attached

      expired_pass = create(:movement_pass, :standalone)
      expired_pass.photos.attach(photo)
      expired_pass.update_column(:expires_at, 1.minute.ago)
      expired_pass.vencer!

      expect(expired_pass.photos).not_to be_attached
    end

    it "no cambia el estado de carga del contenedor" do
      pass = create(:movement_pass)
      expect { pass.completar! }.not_to(change { pass.container.reload.status })
    end

    it "expira en lote los pases vencidos" do
      pass = create(:movement_pass, :standalone)
      pass.update_columns(expires_at: 1.minute.ago)
      described_class.expire_overdue!
      expect(pass.reload).to be_vencido
    end
  end
end

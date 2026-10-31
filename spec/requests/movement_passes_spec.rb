require "rails_helper"

RSpec.describe "Pases de movimiento", type: :request do
  let(:carrier) { create(:carrier) }
  let(:client) { create(:client) }
  let(:assignment) { create(:container_assignment, carrier: carrier) }
  let(:vehicle_params) do
    { "0" => { role: "principal", company_name: "Transportes Golfo", operator_name: "Ana López", plate: "xyz-123", unit_type: "full" } }
  end

  it "requiere sesión" do
    get movement_passes_path
    expect(response).to redirect_to(new_user_session_path)
  end

  context "como transporte" do
    before { sign_in create(:user, :transporte, carrier: carrier) }

    it "lista sus asignaciones pendientes para tramitar" do
      assignment
      create(:container_assignment)
      get new_movement_pass_path
      expect(response.body).to include(assignment.container.number)
    end

    it "muestra el formulario con la empresa precargada" do
      get new_movement_pass_path(assignment_id: assignment.id)
      expect(response.body).to include(carrier.name, "movement_pass[vehicles_attributes][0][operator_name]")
    end

    it "emite el pase con vehículo y muestra el QR" do
      expect {
        post movement_passes_path, params: { assignment_id: assignment.id, movement_pass: { vehicles_attributes: vehicle_params } }
      }.to change(MovementPass, :count).by(1)

      pass = MovementPass.last
      expect(response).to redirect_to(movement_pass_path(pass))
      expect(pass).to have_attributes(movement_type: "ingreso", carrier: carrier, requested_by: User.last)
      expect(pass.vehicle("principal")).to have_attributes(operator_name: "Ana López", plate: "XYZ123", unit_type: "full")

      expect(RQRCode::QRCode).to receive(:new).with(a_string_matching(%r{\Ahttps?://[^/]+#{Regexp.escape(gate_pass_path(pass.token))}\z}), level: :m).and_call_original
      follow_redirect!
      expect(response.body).to include(pass.token, "data:image/svg+xml;base64")
    end

    it "descarga el PDF del pase vigente" do
      pass = create(:movement_pass, container_assignment: assignment)
      expect(RQRCode::QRCode).to receive(:new).with(a_string_matching(%r{\Ahttps?://[^/]+#{Regexp.escape(gate_pass_path(pass.token))}\z}), level: :m).and_call_original

      get movement_pass_path(pass, format: :pdf)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/pdf")
      expect(response.body).to start_with("%PDF")
    end

    it "no descarga un PDF vencido" do
      pass = create(:movement_pass, container_assignment: assignment)
      pass.update_columns(expires_at: 1.minute.ago)
      get movement_pass_path(pass, format: :pdf)
      expect(response).to redirect_to(movement_pass_path(pass))
      expect(pass.reload).to be_vencido
    end

    it "permite emitir un pase nuevo tras cancelar o vencer el anterior" do
      pass = create(:movement_pass, container_assignment: assignment)
      pass.cancelar!
      get new_movement_pass_path
      expect(response.body).to include(assignment.container.number)
      expect {
        post movement_passes_path, params: { assignment_id: assignment.id, movement_pass: { vehicles_attributes: vehicle_params } }
      }.to change(MovementPass, :count).by(1)

      MovementPass.last.update_columns(expires_at: 1.minute.ago)
      get new_movement_pass_path
      expect(response.body).to include(assignment.container.number)
      expect {
        post movement_passes_path, params: { assignment_id: assignment.id, movement_pass: { vehicles_attributes: vehicle_params } }
      }.to change(MovementPass, :count).by(1)
    end

    it "oculta la asignación mientras tenga un pase activo" do
      create(:movement_pass, container_assignment: assignment)
      get new_movement_pass_path
      expect(response.body).not_to include(assignment.container.number)
    end

    it "rechaza datos incompletos del vehículo" do
      expect {
        post movement_passes_path, params: { assignment_id: assignment.id, movement_pass: { vehicles_attributes: { "0" => { role: "principal", operator_name: "" } } } }
      }.not_to change(MovementPass, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "no tramita asignaciones de otro transportista" do
      other = create(:container_assignment)
      expect {
        post movement_passes_path, params: { assignment_id: other.id, movement_pass: { vehicles_attributes: vehicle_params } }
      }.not_to change(MovementPass, :count)
    end

    it "no ve pases ajenos" do
      other = create(:movement_pass)
      get movement_pass_path(other)
      expect(response).to redirect_to(root_path)
    end

    it "cancela su pase vigente" do
      pass = create(:movement_pass, container_assignment: assignment)
      patch cancel_movement_pass_path(pass)
      expect(pass.reload).to be_cancelado
    end

    it "filtra el listado por movimiento" do
      pass = create(:movement_pass, container_assignment: assignment)
      get movement_passes_path(movement_type: "salida")
      expect(response.body).not_to include(pass.container.number)
    end
  end

  context "como cliente con contenedor de resguardo" do
    let(:container) { create(:container, client: client) }

    before { sign_in create(:user, :cliente, client: client) }

    it "no ofrece contenedores cuyo último movimiento fue un traspaleo" do
      transferred = create(:container, client: client)
      pass = create(:movement_pass, :standalone, container: transferred, movement_type: "traspaleo")
      ContainerMovement.create!(container: transferred, movement_pass: pass, movement_type: "traspaleo",
                                user: create(:user, :grua), created_at: Time.current)

      kept = container
      get new_movement_pass_path
      expect(response.body).to include(kept.number)
      expect(response.body).not_to include(transferred.number)
    end

    it "solicita ingreso declarando el estado de carga" do
      expect {
        post movement_passes_path, params: { container_id: container.id, movement_type: "ingreso",
                                             movement_pass: { load_status: "vacio", vehicles_attributes: vehicle_params } }
      }.to change(MovementPass, :count).by(1)
      expect(MovementPass.last).to have_attributes(load_status: "vacio", client: client)
    end

    it "solicita traspaleo con dos vehículos" do
      get new_movement_pass_path(container_id: container.id, movement_type: "traspaleo")
      expect(response.body).to include("vehicles_attributes][1]")

      vehicles = vehicle_params.merge("1" => { role: "destino", company_name: "Otra", operator_name: "Luis", plate: "DEF456", unit_type: "sencillo" })
      expect {
        post movement_passes_path, params: { container_id: container.id, movement_type: "traspaleo", movement_pass: { vehicles_attributes: vehicles } }
      }.to change(MovementPass, :count).by(1)
      expect(MovementPass.last.vehicles.count).to eq(2)
    end

    it "no tramita contenedores de otro cliente ni con MBL" do
      foreign = create(:container)
      with_bl = create(:container, :with_master_bl)
      [ foreign, with_bl ].each do |item|
        expect {
          post movement_passes_path, params: { container_id: item.id, movement_type: "salida", movement_pass: { vehicles_attributes: vehicle_params } }
        }.not_to change(MovementPass, :count)
      end
    end

    it "no inventa traspaleo en el flujo MBL" do
      expect {
        post movement_passes_path, params: { assignment_id: assignment.id, movement_pass: { vehicles_attributes: vehicle_params } }
      }.not_to change(MovementPass, :count)
    end
  end

  context "como Seguridad" do
    before { sign_in create(:user, :seguridad) }

    it "consulta pases pero no puede emitirlos" do
      pass = create(:movement_pass)
      get movement_passes_path
      expect(response.body).to include(pass.container.number)
      movement_type = Nokogiri::HTML(response.body).at_css("[data-movement-type='ingreso']")
      expect(movement_type.text).to include(I18n.t("movement_passes.types.ingreso"))
      expect(movement_type["class"]).to include("font-bold", "bg-emerald-100")

      get new_movement_pass_path
      expect(response).to redirect_to(root_path)
    end
  end
end

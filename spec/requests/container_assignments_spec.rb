require "rails_helper"

RSpec.describe "Asignaciones a transporte", type: :request do
  let(:master_bl) { create(:master_bl) }
  let!(:containers) { create_list(:container, 2, :with_master_bl, master_bl: master_bl) }
  let(:carrier) { create(:carrier) }

  it "requiere sesión" do
    get container_assignments_path
    expect(response).to redirect_to(new_user_session_path)
  end

  context "como admin" do
    before { sign_in create(:user, :admin) }

    it "asigna varios contenedores de un MBL con área y estiba preferidas" do
      area = create(:yard_area, client: master_bl.client, yard_block: create(:yard_block, levels: 3))
      section = create(:yard_area_section, yard_area: area)

      get new_container_assignment_path(master_bl_id: master_bl.id)
      expect(response.body).to include(containers.first.number, section.name)

      expect {
        post container_assignments_path, params: {
          master_bl_id: master_bl.id, container_ids: containers.map(&:id),
          container_assignment: { carrier_id: carrier.id, operation: "ingreso", destination: "section:#{section.id}", preferred_level: 2 }
        }
      }.to change(ContainerAssignment, :count).by(2)

      assignment = ContainerAssignment.last
      expect(assignment).to have_attributes(carrier: carrier, yard_area: area, yard_area_section: section, preferred_level: 2, status: "pendiente")
      expect(assignment.assigned_by).to be_present
      follow_redirect!
      expect(response.body).to include(master_bl.number, carrier.name)
    end

    it "no ofrece áreas de otros clientes ni secciones de otros MBL" do
      mine = create(:yard_area, client: master_bl.client)
      foreign = create(:yard_area)
      reserved = create(:yard_area_section, yard_area: mine, master_bl: create(:master_bl, client: master_bl.client))
      open_section = create(:yard_area_section, yard_area: mine)

      get new_container_assignment_path(master_bl_id: master_bl.id)
      expect(response.body).to include(mine.code, open_section.name)
      expect(response.body).not_to include(foreign.code)
      expect(response.body).not_to include("section:#{reserved.id}")
    end

    it "no guarda nada si alguna asignación es inválida" do
      create(:container_assignment, container: containers.first, carrier: carrier)
      expect {
        post container_assignments_path, params: {
          master_bl_id: master_bl.id, container_ids: containers.map(&:id),
          container_assignment: { carrier_id: carrier.id, operation: "ingreso" }
        }
      }.not_to change(ContainerAssignment, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(containers.first.number)
    end

    it "exige elegir al menos un contenedor" do
      expect {
        post container_assignments_path, params: { master_bl_id: master_bl.id, container_assignment: { carrier_id: carrier.id, operation: "salida" } }
      }.not_to change(ContainerAssignment, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "cancela solo asignaciones pendientes" do
      assignment = create(:container_assignment, container: containers.first, carrier: carrier)
      patch cancel_container_assignment_path(assignment)
      expect(assignment.reload).to be_cancelada

      patch cancel_container_assignment_path(assignment)
      expect(flash[:alert]).to eq(I18n.t("flash.container_assignments.not_cancelable"))
    end

    it "muestra la descripción y la guía interna" do
      get container_assignments_path
      expect(response.body).to include(I18n.t("container_assignments.index.description.internal"), I18n.t("container_assignments.guide.internal.intro"))
      expect(response.body).not_to include(I18n.t("container_assignments.guide.carrier.intro"))
    end

    it "filtra por operación" do
      create(:container_assignment, container: containers.first, operation: "salida")
      get container_assignments_path(operation: "ingreso")
      expect(response.body).not_to include(containers.first.number)
    end
  end

  context "como transporte" do
    let(:user) { create(:user, :transporte, carrier: carrier) }

    before { sign_in user }

    it "muestra descripción y guía rápida sin datos internos" do
      get container_assignments_path
      expect(response.body).to include(I18n.t("container_assignments.index.description.carrier"), I18n.t("container_assignments.guide.carrier.intro"))
      expect(response.body).not_to include(I18n.t("container_assignments.guide.internal.intro"))
    end

    it "muestra el botón Ver pase en lugar de Tramitar cuando ya hay un pase activo" do
      with_pass = create(:container_assignment, container: containers.first, carrier: carrier)
      without_pass = create(:container_assignment, container: containers.last, carrier: carrier)
      pass = create(:movement_pass, container_assignment: with_pass)

      get container_assignments_path
      expect(response.body).to include(movement_pass_path(pass))
      expect(response.body).to include(new_movement_pass_path(assignment_id: without_pass.id))
      expect(response.body).not_to include(new_movement_pass_path(assignment_id: with_pass.id))
    end

    it "ve solo sus asignaciones sin cliente ni ubicación del patio" do
      assignment = create(:container_assignment, container: containers.first, carrier: carrier)
      area = create(:yard_area, client: assignment.container.master_bl.client)
      assignment.update!(yard_area: area)
      get container_assignments_path
      expect(response.body).to include(assignment.container.number, assignment.container.master_bl.number)
      expect(response.body).not_to include(assignment.container.master_bl.client.name, area.code)

      get new_movement_pass_path
      expect(response.body).not_to include(assignment.container.master_bl.client.name)
    end

    it "ve solo sus asignaciones y no puede crear ni cancelar" do
      mine = create(:container_assignment, container: containers.first, carrier: carrier)
      create(:container_assignment, container: containers.last)

      get container_assignments_path
      expect(response.body).to include(mine.container.number)
      expect(response.body).not_to include(containers.last.number)

      expect { post container_assignments_path, params: { master_bl_id: master_bl.id, container_ids: [ containers.last.id ], container_assignment: { carrier_id: carrier.id, operation: "ingreso" } } }
        .not_to change(ContainerAssignment, :count)
      patch cancel_container_assignment_path(mine)
      expect(mine.reload).to be_pendiente
    end
  end

  it "niega el acceso a clientes sin afiliación de transporte" do
    sign_in create(:user, :cliente, client: master_bl.client)
    get container_assignments_path
    expect(response).to redirect_to(root_path)
  end
end

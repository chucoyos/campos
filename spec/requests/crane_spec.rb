require "rails_helper"

RSpec.describe "Grúa", type: :request do
  let(:crane_user) { create(:user, :grua) }
  let!(:order) { create(:work_order) }

  it "exige autenticación" do
    get crane_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "muestra las tareas pendientes con los datos del transporte" do
    sign_in crane_user
    get crane_path

    expect(response).to have_http_status(:ok)
    vehicle = order.movement_pass.vehicle("principal")
    expect(response.body).to include(order.container.number, order.to_yard_slot.code, vehicle.plate, vehicle.operator_name, "Sencillo", "turbo-cable-stream-source")
  end

  it "muestra el estado vacío" do
    order.cancelar!
    sign_in crane_user
    get crane_path

    expect(response.body).to include(I18n.t("crane.index.empty"))
  end

  it "permite buscar y programar un reacomodo para un contenedor que está en patio" do
    block = create(:yard_block, bays: 4, rows: 1, levels: 1)
    source = create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 1)
    destination = create(:yard_slot, yard_block: block, bay: 2, row: "A", level: 1)
    candidate = create(:container, current_yard_slot: source)
    elsewhere = create(:container)
    sign_in crane_user

    get search_crane_rehandles_path, params: { q: candidate.number }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(candidate.number)
    expect(response.body).not_to include(elsewhere.number)

    get new_crane_rehandle_path, params: { container_id: candidate.id }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(source.code, destination.code)

    expect {
      post create_crane_rehandle_path, params: { container_id: candidate.id, yard_slot_id: destination.id }
    }.to change(WorkOrder, :count).by(1)

    expect(response).to redirect_to(crane_path)
    expect(WorkOrder.last).to have_attributes(
      container: candidate, movement_type: "reacomodo", from_yard_slot: source, to_yard_slot: destination
    )
  end

  it "muestra una salida bloqueada con el siguiente reacomodo y su progreso" do
    block = create(:yard_block, bays: 4, rows: 1, levels: 3)
    target_slot = create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 1)
    blocker_slot = create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 2)
    top_slot = create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 3)
    create(:yard_slot, yard_block: block, bay: 3, row: "A", level: 1)
    create(:yard_slot, yard_block: block, bay: 4, row: "A", level: 1)
    target = create(:container, current_yard_slot: target_slot)
    blocker = create(:container, current_yard_slot: blocker_slot)
    top = create(:container, current_yard_slot: top_slot)
    pass = create(:movement_pass, :standalone, container: target, movement_type: "salida", load_status: nil)

    GateMovementService.call(pass:, user: create(:user, :seguridad))
    first_order = WorkOrder.find_by!(rehandling_request: RehandlingRequest.find_by!(movement_pass: pass))
    CraneTaskService.complete(work_order: first_order, user: crane_user)

    sign_in crane_user
    get crane_path

    expect(response).to have_http_status(:ok)
    request_card = Nokogiri::HTML(response.body).at_css("#rehandling_request_#{RehandlingRequest.find_by!(movement_pass: pass).id}")
    expect(request_card.text).to include(target.number, blocker.number, "Reacomodos completados: 1", "Salida bloqueada")
    expect(request_card.css("article#work_order_#{WorkOrder.find_by!(rehandling_request: RehandlingRequest.find_by!(movement_pass: pass), status: "pendiente").id}").size).to eq(1)
  end

  it "agrupa la carga con la solicitud y deja de indicar salida bloqueada cuando ya no hay bloqueadores" do
    block = create(:yard_block, bays: 4, rows: 1, levels: 2)
    target_slot = create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 1)
    blocker_slot = create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 2)
    create(:yard_slot, yard_block: block, bay: 3, row: "A", level: 1)
    create(:yard_slot, yard_block: block, bay: 4, row: "A", level: 1)
    target = create(:container, current_yard_slot: target_slot)
    blocker = create(:container, current_yard_slot: blocker_slot)
    pass = create(:movement_pass, :standalone, container: target, movement_type: "salida", load_status: nil)

    GateMovementService.call(pass:, user: create(:user, :seguridad))
    rehandle_order = WorkOrder.find_by!(rehandling_request: RehandlingRequest.find_by!(movement_pass: pass))
    CraneTaskService.complete(work_order: rehandle_order, user: crane_user)

    sign_in crane_user
    get crane_path

    request = RehandlingRequest.find_by!(movement_pass: pass)
    load_order = WorkOrder.find_by!(movement_pass: pass, status: "pendiente")
    request_card = Nokogiri::HTML(response.body).at_css("#rehandling_request_#{request.id}")
    expect(response).to have_http_status(:ok)
    expect(request_card.text).to include(target.number, blocker.number, "Salida desbloqueada", "Columna despejada")
    expect(request_card.text).not_to include("Salida bloqueada")
    expect(request_card.css("article#work_order_#{load_order.id}").size).to eq(1)
    expect(Nokogiri::HTML(response.body).css("article#work_order_#{load_order.id}").size).to eq(1)
  end

  it "concluye la tarea" do
    sign_in crane_user

    expect { patch complete_crane_work_order_path(order) }.to change(ContainerMovement, :count).by(1)

    expect(response).to redirect_to(crane_path)
    expect(order.reload).to be_completada
    expect(order.container.reload.current_yard_slot).to eq(order.to_yard_slot)
  end

  it "informa si no se puede concluir" do
    order.to_yard_slot.update!(enabled: false)
    sign_in crane_user
    patch complete_crane_work_order_path(order)

    expect(response).to redirect_to(crane_path)
    expect(flash[:alert]).to eq(I18n.t("crane.errors.destination_unavailable"))
    expect(order.reload).to be_pendiente
  end

  it "solo el admin puede cancelar" do
    sign_in crane_user
    patch cancel_crane_work_order_path(order)
    expect(order.reload).to be_pendiente

    sign_out crane_user
    sign_in create(:user, :admin)
    patch cancel_crane_work_order_path(order)
    expect(order.reload).to be_cancelada
  end

  it "niega el acceso a Seguridad y aterriza a la grúa en su vista" do
    sign_in create(:user, :seguridad)
    get crane_path
    expect(response).to redirect_to(root_path)

    sign_out :user
    sign_in crane_user
    get root_path
    expect(response).to redirect_to(crane_path)
  end

  it "muestra la etiqueta de pendiente en el detalle del contenedor" do
    sign_in create(:user, :admin)
    get container_path(order.container)

    expect(response.body).to include(I18n.t("crane.pending_badge"))
  end
end

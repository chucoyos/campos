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

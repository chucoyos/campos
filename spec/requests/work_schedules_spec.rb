require "rails_helper"

RSpec.describe "Programación", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:crane_user) { create(:user, :grua) }
  let(:master_bl) { create(:master_bl) }
  let(:yard) { create(:yard_block, bays: 4, rows: 1, levels: 1) }
  let(:desycon) { create(:yard_block, code: "1CFS", bays: 4, rows: 2, levels: 1) }
  let!(:slot) { create(:yard_slot, yard_block: yard, bay: 1, row: "A", level: 1) }
  let!(:desycon_slot) { create(:yard_slot, yard_block: desycon, bay: 1, row: "A", level: 1) }
  let!(:container) { create(:container, master_bl:, current_yard_slot: slot) }

  it "exige rol de administrador" do
    sign_in crane_user
    get work_schedules_path
    expect(response).to redirect_to(root_path)
  end

  it "lista los contenedores en patio de un MBL, crea la programación y la muestra" do
    sign_in admin
    get new_work_schedule_path(master_bl_id: master_bl.id)
    expect(response.body).to include(container.number, slot.code)

    expect do
      post work_schedules_path, params: { master_bl_id: master_bl.id, container_ids: [ container.id ], scheduled_for: Date.current }
    end.to change(WorkOrder, :count).by(1)
    schedule = WorkSchedule.last
    expect(response).to redirect_to(work_schedule_path(schedule))

    get work_schedule_path(schedule)
    expect(response.body).to include(container.number, desycon_slot.code)
    get work_schedules_path
    expect(response.body).to include(master_bl.number, "0 de 1")
  end

  it "avisa cuando no se selecciona ningún contenedor" do
    sign_in admin
    post work_schedules_path, params: { master_bl_id: master_bl.id, scheduled_for: Date.current }
    expect(response).to redirect_to(new_work_schedule_path(master_bl_id: master_bl.id))
    expect(flash[:alert]).to include("al menos un contenedor")
  end

  it "separa la cola de Programación de la cola normal en la consola de la grúa" do
    schedule = WorkScheduleService.create(container_ids: [ container.id ], scheduled_for: Date.current, user: admin, master_bl:)
    other = create(:work_order)
    sign_in crane_user

    get crane_path
    expect(response.body).to include(other.container.number)
    expect(response.body).not_to include(container.number)

    get crane_path(queue: "scheduled")
    html = Nokogiri::HTML(response.body)
    expect(html.at_css("#work_order_#{schedule.work_orders.sole.id}").text).to include(container.number, slot.code)
    expect(response.body).to include(master_bl.number)
    expect(response.body).not_to include(other.container.number)

    patch complete_crane_work_order_path(schedule.work_orders.sole, queue: "scheduled"),
      params: { yard_slot_id: desycon_slot.id }
    expect(response).to redirect_to(crane_path(queue: "scheduled"))
    expect(container.reload.current_yard_slot).to eq(desycon_slot)
    expect(schedule.reload).to be_completada
  end

  it "cancela una programación activa" do
    schedule = WorkScheduleService.create(container_ids: [ container.id ], scheduled_for: Date.current, user: admin, master_bl:)
    sign_in admin

    patch cancel_work_schedule_path(schedule)

    expect(schedule.reload).to be_cancelada
    expect(WorkOrder.where(status: "pendiente")).to be_empty
  end
end

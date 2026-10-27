require "rails_helper"

RSpec.describe "Patio", type: :request do
  before { YardCatalog.new(blocks: [ { code: "1A", bays: 4, rows: 2, levels: 2 } ]).call }

  let(:slot) { YardSlot.find_by!(code: "1A1A1") }

  it "requires login" do
    get yard_path
    expect(response).to redirect_to(new_user_session_path)
  end

  %i[admin seguridad].each do |role|
    it "lets #{role} see blocks and positions" do
      sign_in create(:user, role)
      get yard_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1A1A1")
    end
  end

  it "renders the 3D map with the block definitions" do
    sign_in create(:user, :admin)
    get yard_path
    expect(response.body).to include('data-controller="yard-map"')
    expect(response.body).to include("1A")
    expect(response.body).to include('data-yard-map-target="block"')
  end

  it "includes the containers currently occupying positions in the 3D map data" do
    sign_in create(:user, :admin)
    occupied_20 = create(:container, current_yard_slot: slot)
    occupied_40 = create(:container, :with_master_bl, size: 40, current_yard_slot: YardSlot.find_by!(code: "1A3A1"))

    get yard_path

    expect(response.body).to include('data-yard-map-occupied-value=', occupied_20.number, occupied_40.number)
    expect(response.body).to include("Ocupada · contenedor")
  end

  it "filters by level and state" do
    sign_in create(:user, :admin)
    slot.update!(enabled: false)
    get yard_path, params: { level: 2 }
    expect(response.body).to include("1A1A2")
    expect(response.body).not_to include("1A1A1<")

    get yard_path, params: { enabled: "false" }
    expect(response.body).to include("1A1A1")
    expect(response.body).not_to include("1A2A1")
  end

  %i[cliente transporte grua montacargas].each do |role|
    it "denies #{role}" do
      sign_in create(:user, role)
      get yard_path
      expect(response).to have_http_status(:found)
      expect(response).not_to have_http_status(:ok)
    end
  end

  it "lets admin disable and enable a position" do
    sign_in create(:user, :admin)
    patch toggle_yard_slot_path(slot)
    expect(slot.reload).not_to be_enabled
    patch toggle_yard_slot_path(slot)
    expect(slot.reload).to be_enabled
  end

  it "does not let seguridad change positions, but lets them see the toggle-free list" do
    sign_in create(:user, :seguridad)
    patch toggle_yard_slot_path(slot)
    expect(slot.reload).to be_enabled
    get yard_path
    expect(response.body).not_to include(toggle_yard_slot_path(slot))
  end
end

require "rails_helper"

RSpec.describe "Áreas del patio", type: :request do
  let(:block) { create(:yard_block, code: "1C", bays: 4, rows: 2, levels: 1) }
  let(:client) { create(:client) }

  it "requiere sesión" do
    get yard_areas_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "niega el acceso a clientes" do
    sign_in create(:user, :cliente, client: client)
    get yard_areas_path
    expect(response).to redirect_to(root_path)
  end

  it "deja a Seguridad consultar pero no crear" do
    area = create(:yard_area)
    sign_in create(:user, :seguridad)
    get yard_area_path(area)
    expect(response).to have_http_status(:ok)
    expect { post yard_areas_path, params: { yard_area: { code: "X", name: "X", yard_block_id: block.id } } }.not_to change(YardArea, :count)
  end

  context "como admin" do
    before { sign_in create(:user, :admin) }

    it "crea un área y sus secciones con posiciones" do
      expect {
        post yard_areas_path, params: { yard_area: { code: "ar-1", name: "Cliente A", yard_block_id: block.id, client_id: client.id } }
      }.to change(YardArea, :count).by(1)
      area = YardArea.last
      expect(area.code).to eq("AR-1")

      bl = create(:master_bl, client: client)
      post yard_area_sections_path(area), params: { yard_area_section: { name: "Norte", master_bl_id: bl.id } }
      section = area.sections.last
      expect(section.master_bl).to eq(bl)

      create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 1)
      post assign_slots_yard_area_section_path(area, section), params: { bay_from: 1, bay_to: 4, rows: %w[A], levels: %w[1] }
      expect(section.yard_slots.count).to eq(1)

      post release_slots_yard_area_section_path(area, section), params: { bay_from: 1, bay_to: 4, rows: %w[A], levels: %w[1] }
      expect(section.yard_slots.count).to eq(0)
      post assign_slots_yard_area_section_path(area, section), params: { bay_from: 1, bay_to: 4, rows: %w[A], levels: %w[1] }

      get yard_area_path(area)
      expect(response.body).to include("Norte", "Nivel 1 · Fila A · Bahías 1")
      get yard_areas_path
      expect(response.body).to include("AR-1")
    end

    it "muestra las secciones en el mapa del patio" do
      section = create(:yard_area_section, name: "Norte")
      create(:yard_slot, yard_block: section.yard_area.yard_block, bay: 1, row: "A", level: 1, yard_area_section: section)
      get yard_path
      expect(response.body).to include("data-yard-map-sections-value", "Norte")
    end

    it "ofrece la guía rápida en el listado, el detalle y el patio" do
      area = create(:yard_area)
      [ yard_areas_path, yard_area_path(area), yard_path ].each do |path|
        get path
        expect(response.body).to include('data-controller="modal"', I18n.t("yard_areas.guide.title"))
      end
    end

    it "no elimina un área con secciones" do
      section = create(:yard_area_section)
      expect { delete yard_area_path(section.yard_area) }.not_to change(YardArea, :count)
    end
  end
end

require "rails_helper"

RSpec.describe "Warehouse", type: :request do
  let!(:slot) { create(:warehouse_slot, number: 3) }
  let(:item) do
    create(:cargo_item, description: "Rollo ubicable").tap do |line|
      line.cargo_manifest.update_columns(status: "confirmed", confirmed_at: Time.current)
    end
  end

  context "as a forklift operator" do
    before { sign_in create(:user, :montacargas) }

    it "shows the map, labels and a slot" do
      get warehouse_path
      expect(response.body).to include("N1-03")

      get warehouse_labels_path
      expect(response).to have_http_status(:ok)

      get warehouse_slot_path(slot)
      expect(response.body).to include("Subdivisión A")
    end

    it "stores a line in a section of the slot" do
      patch store_warehouse_slot_path(slot), params: { cargo_item_id: item.id, section: "B" }

      expect(response).to redirect_to(warehouse_slot_path(slot))
      expect(item.reload).to have_attributes(warehouse_slot: slot, slot_section: "B", status: "stored")
    end

    it "does not store lines of a draft capture" do
      draft = create(:cargo_item)

      patch store_warehouse_slot_path(slot), params: { cargo_item_id: draft.id, section: "A" }

      expect(response).to have_http_status(:not_found)
      expect(draft.reload).to be_captured
    end

    it "shows an error for an invalid section" do
      patch store_warehouse_slot_path(slot), params: { cargo_item_id: item.id, section: "Z" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(item.reload).to be_captured
    end
  end

  it "denies clients" do
    sign_in create(:user, :cliente, client: create(:client))
    get warehouse_path
    expect(response).not_to have_http_status(:ok)
  end

  it "lets security view but not store" do
    sign_in create(:user, :seguridad)
    get warehouse_slot_path(slot)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Ubicar mercancía aquí")

    patch store_warehouse_slot_path(slot), params: { cargo_item_id: item.id, section: "A" }
    expect(item.reload).to be_captured
  end
end

RSpec.describe "Warehouse map data", type: :request do
  it "embeds the map with sections and the free space of bay 1" do
    WarehouseCatalog.new.call
    sign_in create(:user, :admin)

    get warehouse_path

    expect(response.body).to include("data-controller=\"warehouse-map\"", "free_space_after&quot;:4")
    expect(response.body).not_to include("N1-08")
  end
end

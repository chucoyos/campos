require "rails_helper"

RSpec.describe "Cargo capture", type: :request do
  let(:client) { create(:client) }
  let(:packaging) { create(:cargo_packaging) }

  context "as an administrator" do
    before { sign_in create(:user, :admin) }

    it "creates general-cargo records without an MBL or container for a client" do
      expect do
        post cargo_manifests_path, params: { cargo_manifest: { client_id: client.id, container_id: "" } }
      end.to change(CargoManifest, :count).by(1)

      expect(CargoManifest.last).to have_attributes(client: client, container: nil)
    end

    it "creates a roll with optional source identifier and QR" do
      manifest = create(:cargo_manifest, client: client)

      expect do
        post cargo_manifest_cargo_items_path(manifest), params: {
          cargo_item: { cargo_packaging_id: packaging.id, description: "Rollo", quantity: 1, weight_kg: 750 }
        }
      end.to change(CargoItem, :count).by(1)

      expect(CargoItem.last).to have_attributes(origin_identifier: nil, qr_token: nil)
    end

    it "provides a QR when requested for an eligible item" do
      manifest = create(:cargo_manifest, client: client)

      post cargo_manifest_cargo_items_path(manifest), params: {
        cargo_item: { cargo_packaging_id: packaging.id, description: "Rollo", quantity: 1, weight_kg: 750, generate_qr: "1" }
      }

      expect(CargoItem.last.qr_token).to be_present
      expect(response).to redirect_to(cargo_manifest_path(manifest))
    end

    it "renders QR and item actions using the nested cargo item routes" do
      manifest = create(:cargo_manifest, client: client)
      item = create(:cargo_item, cargo_manifest: manifest, cargo_packaging: packaging, qr_token: "qr-token-123")

      get cargo_manifest_path(manifest)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(cargo_manifest_cargo_item_path(manifest, item, token: item.qr_token))
      expect(response.body).to include(cargo_manifest_cargo_item_path(manifest, item))
    end

    it "does not allow a QR on aggregated boxes" do
      box = create(:cargo_packaging, :box)
      manifest = create(:cargo_manifest, client: client)

      expect do
        post cargo_manifest_cargo_items_path(manifest), params: {
          cargo_item: { cargo_packaging_id: box.id, description: "Cajas", quantity: 3, generate_qr: "1" }
        }
      end.not_to change(CargoItem, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "reopening a confirmed record" do
    let(:manifest) { create(:cargo_manifest, :confirmed, client: client) }

    it "lets an administrator reopen it and edit its items again" do
      sign_in create(:user, :admin)

      patch reopen_cargo_manifest_path(manifest)

      expect(manifest.reload).to have_attributes(status: "draft", confirmed_at: nil)
      expect do
        post cargo_manifest_cargo_items_path(manifest), params: {
          cargo_item: { cargo_packaging_id: packaging.id, description: "Rollo", quantity: 1, weight_kg: 750 }
        }
      end.to change(CargoItem, :count).by(1)
    end

    it "does not let security staff reopen it" do
      sign_in create(:user, :seguridad)

      patch reopen_cargo_manifest_path(manifest)

      expect(manifest.reload).to be_confirmed
    end
  end

  describe "template download" do
    before { sign_in create(:user, :admin) }

    it "names the file after the container" do
      container = create(:container, :with_master_bl, number: "ONEU1234567")
      manifest = create(:cargo_manifest, client: container.master_bl.client, container: container)

      get template_cargo_manifest_path(manifest)

      expect(response.headers["Content-Disposition"]).to include("mercancias_ONEU1234567.xlsx")
    end
  end

  describe "description suggestions" do
    before { sign_in create(:user, :admin) }

    it "suggests steel options while accepting free text" do
      manifest = create(:cargo_manifest, client: client)

      get cargo_manifest_path(manifest)
      expect(response.body).to include('<option value="Acero">', '<option value="Lingote de Acero">')

      post cargo_manifest_cargo_items_path(manifest), params: {
        cargo_item: { cargo_packaging_id: packaging.id, description: "Bobinas de cobre", quantity: 1, weight_kg: 500 }
      }
      expect(manifest.cargo_items.last.description).to eq("Bobinas de cobre")
    end
  end

  describe "item edit panel" do
    before { sign_in create(:user, :admin) }

    it "renders a hidden edit form with cancel, separate from the summary actions" do
      manifest = create(:cargo_manifest, client: client)
      create(:cargo_item, cargo_manifest: manifest, cargo_packaging: packaging)

      get cargo_manifest_path(manifest)

      expect(response.body).to include('data-controller="item-edit"', 'data-action="item-edit#open"', 'data-action="item-edit#close"')
      expect(response.body).to match(/data-item-edit-target="form" hidden/)
    end
  end

  describe "index" do
    before { sign_in create(:user, :admin) }

    it "shows the line count per record without N+1 queries" do
      create_list(:cargo_item, 2, cargo_manifest: create(:cargo_manifest, client: client), cargo_packaging: packaging)
      create(:cargo_manifest, client: client)

      get cargo_manifests_path

      expect(response.body).to include("2 líneas")
      expect(response.body).to include("0 líneas")
    end
  end

  describe "new record form" do
    let(:master_bl) { create(:master_bl, client: client) }
    let!(:free) { create(:container, :with_master_bl, master_bl: master_bl) }
    let!(:taken) { create(:container, :with_master_bl, master_bl: create(:master_bl, client: client)) }

    before do
      create(:cargo_manifest, client: client, container: taken)
      sign_in create(:user, :admin)
    end

    it "preselects general cargo and lists only containers without a record, with their MBL" do
      get new_cargo_manifest_path

      expect(response.body).to match(/value="general"[^>]*checked/)
      expect(response.body).to include("#{free.number} · #{master_bl.number}")
      expect(response.body).not_to include(taken.number)
    end

    it "keeps creating general cargo for clients without a container parameter" do
      sign_in create(:user, :cliente, client: client)

      expect do
        post cargo_manifests_path, params: { cargo_manifest: { container_id: "" } }
      end.to change(CargoManifest, :count).by(1)
    end
  end

  describe "container detail" do
    let(:master_bl) { create(:master_bl, client: client) }
    let(:container) { create(:container, :with_master_bl, master_bl: master_bl) }
    let(:manifest) { create(:cargo_manifest, client: client, container: container) }

    before { sign_in create(:user, :admin) }

    it "lists the container's cargo and links item management back to the container" do
      create(:cargo_item, cargo_manifest: manifest, cargo_packaging: packaging, description: "Rollo de acero")

      get container_path(container)

      expect(response.body).to include("Rollo de acero")
      expect(response.body).to include(cargo_manifest_cargo_items_path(manifest))
    end

    it "offers to start a cargo record and returns to the container" do
      empty = create(:container, :with_master_bl)

      get container_path(empty)
      expect(response.body).to include(cargo_manifests_path)

      post cargo_manifests_path, params: { return_to: "container", cargo_manifest: { container_id: empty.id, client_id: empty.master_bl.client_id } }
      expect(response).to redirect_to(container_path(empty))
    end

    it "returns to the container after adding an item" do
      post cargo_manifest_cargo_items_path(manifest), headers: { "HTTP_REFERER" => container_url(container) }, params: {
        cargo_item: { cargo_packaging_id: packaging.id, description: "Rollo", quantity: 1, weight_kg: 750 }
      }

      expect(response).to redirect_to(container_url(container))
    end
  end

  context "as a client" do
    before { sign_in create(:user, :cliente, client: client) }

    it "forces general-cargo records to the signed-in client's account" do
      other_client = create(:client)
      post cargo_manifests_path, params: { cargo_manifest: { client_id: other_client.id, container_id: "" } }

      expect(CargoManifest.last.client).to eq(client)
    end

    it "cannot view another client's cargo record" do
      manifest = create(:cargo_manifest)

      get cargo_manifest_path(manifest)

      expect(response).to have_http_status(:not_found)
    end
  end

  it "requires login" do
    get cargo_manifests_path
    expect(response).to redirect_to(new_user_session_path)
  end
end

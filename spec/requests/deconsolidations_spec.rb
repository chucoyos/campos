require "rails_helper"

RSpec.describe "Desconsolidaciones y montacargas", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:forklift) { create(:user, :montacargas) }
  let(:desycon) { create(:yard_block, code: "1CFS", bays: 4, rows: 2, levels: 1) }
  let!(:desycon_slot) { create(:yard_slot, yard_block: desycon, bay: 1, row: "A", level: 1) }
  let(:container) { create(:container, :with_master_bl, current_yard_slot: desycon_slot).tap(&:llenar!) }
  let(:manifest) { create(:cargo_manifest, container:, client: container.master_bl.client) }
  let!(:item) do
    create(:cargo_item, cargo_manifest: manifest, generate_qr: true).tap do
      manifest.update_columns(status: "confirmed", confirmed_at: Time.current)
    end
  end
  let!(:warehouse_slot) { create(:warehouse_slot) }

  it "lista contenedores en DESYCON, inicia y muestra el detalle" do
    sign_in admin
    get deconsolidations_path
    expect(response.body).to include(container.number)

    expect { post deconsolidations_path(container_id: container.id) }.to change(Deconsolidation, :count).by(1)
    get deconsolidation_path(Deconsolidation.last)
    expect(response.body).to include(container.number, "Iniciar desconsolidación")
  end

  it "lista desconsolidaciones existentes sin consultas de más (Bullet)" do
    sign_in admin
    create(:deconsolidation, container:, status: "desconsolidando")
    get deconsolidations_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(container.number)
  end

  it "imprime las etiquetas QR de los bultos con QR" do
    sign_in admin
    deconsolidation = create(:deconsolidation, container:)
    get labels_deconsolidation_path(deconsolidation)
    expect(response.body).to include(item.description, "<svg", deconsolidation_path(deconsolidation))
  end

  it "regresa a la desconsolidación al subir fotos desde ella y acepta solo rutas internas" do
    sign_in admin
    deconsolidation = create(:deconsolidation, container:)
    photo = fixture_file_upload(Rails.root.join("public/icon.png"), "image/png")

    post upload_photos_container_path(container, section: "opening", return_to: deconsolidation_path(deconsolidation)), params: { photos: [ photo ] }
    expect(response).to redirect_to(deconsolidation_path(deconsolidation))

    post upload_photos_container_path(container, section: "opening", return_to: "https://evil.example/x"), params: { photos: [ fixture_file_upload(Rails.root.join("public/icon.png"), "image/png") ] }
    expect(response).to redirect_to(container_path(container))
  end

  it "niega el acceso a montacargas" do
    sign_in forklift
    get deconsolidations_path
    expect(response).to redirect_to(root_path)
  end

  describe "consola de montacargas" do
    before { sign_in forklift }

    it "ubica el bulto escaneando su QR y luego la ubicación" do
      deconsolidation = create(:deconsolidation, container:, status: "desconsolidando")
      get forklift_path
      expect(response.body).to include(item.identifier_label)
      expect(response.body).to include(item.description)

      post forklift_pick_path, params: { code: "http://x/cargo_manifests/1/cargo_items/#{item.id}?token=#{item.qr_token}" }
      expect(response).to redirect_to(forklift_path(item_id: item.id))

      post forklift_store_path, params: { item_id: item.id, code: "http://x/warehouse_slots/#{warehouse_slot.qr_token}", section: "A" }
      expect(response).to redirect_to(forklift_path)
      expect(item.reload).to be_stored
      expect(item.warehouse_slot).to eq(warehouse_slot)
      expect(deconsolidation.reload.stored_count).to eq(1)

      follow_redirect!
      expect(response.body).not_to include(container.number)
    end

    it "sugiere las ubicaciones habilitadas al buscar el destino" do
      create(:deconsolidation, container:, status: "desconsolidando")
      get forklift_path(item_id: item.id)
      expect(response.body).to include(%(<option value="#{warehouse_slot.code}">))
      expect(response.body).to include("Volver al paso anterior")
    end

    it "acepta el código corto de la ubicación" do
      create(:deconsolidation, container:, status: "desconsolidando")
      post forklift_store_path, params: { item_id: item.id, code: warehouse_slot.code.downcase, section: "A" }
      expect(item.reload.warehouse_slot).to eq(warehouse_slot)
    end

    it "no ubica mientras el contenedor sigue en apertura" do
      create(:deconsolidation, container:)
      post forklift_store_path, params: { item_id: item.id, code: warehouse_slot.qr_token, section: "A" }
      expect(item.reload).to be_captured
    end

    it "rechaza un QR de bulto desconocido" do
      post forklift_pick_path, params: { code: "nope" }
      expect(response).to redirect_to(forklift_path)
      expect(flash[:alert]).to be_present
    end
  end
end

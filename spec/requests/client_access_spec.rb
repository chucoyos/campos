require "rails_helper"

RSpec.describe "Acceso del cliente", type: :request do
  let(:client) { create(:client) }
  let(:other_client) { create(:client) }
  let(:user) { create(:user, :cliente, client: client) }
  let!(:own_bl) { create(:master_bl, client: client) }
  let!(:other_bl) { create(:master_bl, client: other_client) }
  let(:pdf) { ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4"), filename: "d.pdf", content_type: "application/pdf") }

  before { sign_in user }

  describe "MBL" do
    it "solo lista sus MBL" do
      get master_bls_path
      expect(response.body).to include(own_bl.number)
      expect(response.body).not_to include(other_bl.number)
    end

    it "no puede ver MBL ajenos (404)" do
      get master_bl_path(other_bl)
      expect(response).to have_http_status(:not_found)
    end

    it "crea MBL siempre a su nombre, ignorando client_id enviado" do
      post master_bls_path, params: { master_bl: { number: "MBL-NEW", client_id: other_client.id } }

      expect(MasterBl.find_by(number: "MBL-NEW").client).to eq(client)
    end

    it "carga el documento de su MBL abierto" do
      patch upload_document_master_bl_path(own_bl), params: { document: pdf.signed_id }
      expect(own_bl.reload.document).to be_attached
    end

    it "no carga documento en MBL ajeno" do
      patch upload_document_master_bl_path(other_bl), params: { document: pdf.signed_id }
      expect(other_bl.reload.document).not_to be_attached
    end

    it "no puede eliminar MBL" do
      expect { delete master_bl_path(own_bl) }.not_to change(MasterBl, :count)
    end

    it "no puede reasignar su MBL a otro cliente" do
      patch master_bl_path(own_bl), params: { master_bl: { client_id: other_client.id } }
      expect(own_bl.reload.client).to eq(client)
    end

    it "queda de solo lectura cuando un contenedor avanzó de estado" do
      create(:container, :with_master_bl, master_bl: own_bl).tap { |c| c.update_columns(status: "lleno") }

      patch master_bl_path(own_bl), params: { master_bl: { number: "CAMBIADO" } }
      expect(own_bl.reload.number).not_to eq("CAMBIADO")

      patch upload_document_master_bl_path(own_bl), params: { document: pdf.signed_id }
      expect(own_bl.reload.document).not_to be_attached
    end
  end

  describe "contenedores" do
    it "crea contenedores en su MBL" do
      expect {
        post containers_path, params: { container: { number: "MSKU1234567", size: 20, container_type: "standard", master_bl_id: own_bl.id } }
      }.to change { own_bl.containers.count }.by(1)
      expect(own_bl.containers.last.status).to eq("activo")
    end

    it "no crea contenedores en MBL ajeno" do
      expect {
        post containers_path, params: { container: { number: "MSKU1234567", size: 20, container_type: "standard", master_bl_id: other_bl.id } }
      }.not_to change(Container, :count)
    end

    it "crea contenedores de resguardo a su nombre sin aceptar otro cliente" do
      post containers_path, params: { container: { number: "MSKU7654321", size: 20, container_type: "standard", status: "lleno", client_id: other_bl.client_id } }
      expect(Container.find_by(number: "MSKU7654321").client_id).to eq(own_bl.client_id)
    end

    it "solo lista y ve contenedores de sus MBL" do
      own = create(:container, :with_master_bl, master_bl: own_bl)
      other = create(:container, :with_master_bl, master_bl: other_bl)

      get containers_path
      expect(response.body).to include(own.number)
      expect(response.body).not_to include(other.number)

      get container_path(other)
      expect(response).to have_http_status(:not_found)
    end

    it "ve y descarga fotos de su contenedor, pero no de uno ajeno" do
      own = create(:container, :with_master_bl, master_bl: own_bl)
      get container_path(own)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(photos_container_path(own))
      get photos_container_path(own, section: "opening")
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("remove_photo", "upload_photos")
      post zip_photos_container_path(own), params: { section: "opening" }
      expect(response).not_to have_http_status(:not_found)
      get photos_container_path(create(:container, :with_master_bl, master_bl: other_bl), section: "opening")
      expect(response).to have_http_status(:not_found)
    end

    it "no puede eliminar, subir/quitar fotos ni cambiar el estado" do
      own = create(:container, :with_master_bl, master_bl: own_bl)

      expect { delete container_path(own) }.not_to change(Container, :count)
      post upload_photos_container_path(own), params: { section: "opening", photos: [ pdf.signed_id ] }
      expect(own.reload.photos_attachments.count).to eq(0) if own.respond_to?(:photos_attachments)
      patch container_path(own), params: { container: { status: "lleno" } }
      expect(own.reload.status).to eq("activo")
    end

    it "no puede mover el contenedor a otro MBL" do
      own = create(:container, :with_master_bl, master_bl: own_bl)
      patch container_path(own), params: { container: { master_bl_id: other_bl.id } }
      expect(own.reload.master_bl).to eq(own_bl)
    end
  end

  it "no accede a catálogos ni usuarios" do
    [ clients_path, carriers_path, users_path ].each do |path|
      get path
      expect(response).to redirect_to(root_path).or redirect_to(client_root_path)
    end
  end

  it "un usuario cliente sin cliente vinculado no ve nada" do
    sign_in create(:user, :cliente)
    get master_bls_path
    expect(response).to redirect_to(root_path).or redirect_to(client_root_path)
  end
end

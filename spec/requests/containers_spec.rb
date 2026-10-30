require "rails_helper"

RSpec.describe "Containers", type: :request do
  let!(:record) { create(:container, :with_master_bl) }
  let(:master_bl) { create(:master_bl) }

  context "as admin" do
    before { sign_in create(:user, :admin) }

    it "lists and shows records" do
      get containers_path
      expect(response.body).to include(record.number, container_path(record))
      get container_path(record)
      expect(response.body).to include(record.number)
    end

    let(:client) { create(:client) }

    it "creates a record without MBL" do
      expect { post containers_path, params: { container: { number: "msku1234567", size: 40, container_type: "hq", status: "vacio", client_id: client.id } } }.to change(Container, :count).by(1)
      expect(Container.last).to have_attributes(number: "MSKU1234567", size: 40, container_type: "hq", status: "vacio", master_bl: nil, client_id: client.id)
      expect(flash[:notice]).to eq(I18n.t("flash.containers.create"))
    end

    it "creates a record linked to an MBL as activo" do
      post containers_path, params: { container: { number: "MSKU7654321", size: 20, container_type: "standard", status: "vacio", master_bl_id: master_bl.id } }
      expect(Container.last).to have_attributes(master_bl: master_bl, status: "activo")
    end

    it "rejects an invalid number format" do
      expect { post containers_path, params: { container: { number: "ABC123", size: 20, container_type: "standard" } } }.not_to change(Container, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "requires an explicit status without MBL" do
      get new_container_path
      expect(response.body).to include(I18n.t("containers.form.status_prompt"))
      expect(response.body).not_to match(/<option selected[^>]*>/)
      expect { post containers_path, params: { container: { number: "MSKU3333333", size: 20, container_type: "standard", status: "" } } }.not_to change(Container, :count)
    end

    it "wires the form to hide the status when an MBL is selected" do
      get new_container_path
      expect(response.body).to include('data-controller="container-form"', 'data-container-form-target="statusField"')
    end

    it "rejects an invalid status without MBL" do
      expect { post containers_path, params: { container: { number: "MSKU1111111", size: 20, container_type: "standard", status: "entregado" } } }.not_to change(Container, :count)
    end

    it "lets the admin correct the status in any direction while the container is outside the yard" do
      patch container_path(record), params: { container: { status: "vacio" } }
      expect(record.reload).to be_vacio
      patch container_path(record), params: { container: { status: "entregado" } }
      expect(record.reload).to be_entregado
      patch container_path(record), params: { container: { status: "lleno" } }
      expect(record.reload).to be_lleno
    end

    it "blocks activo and entregado while the container is in a yard position" do
      slot = create(:yard_slot)
      record.update!(current_yard_slot: slot)
      record.llenar!
      patch container_path(record), params: { container: { size: 40, status: "entregado" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).not_to include("translation missing", "Translation missing")
      expect(response.body).to include("siga en una posición de patio")
      expect(record.reload).to be_lleno
      expect(record.size).not_to eq(40)
      patch container_path(record), params: { container: { status: "activo" } }
      expect(record.reload).to be_lleno
      patch container_path(record), params: { container: { status: "vacio" } }
      expect(record.reload).to be_vacio
    end

    it "does not change the status of containers without MBL or with unknown values" do
      standalone = create(:container)
      patch container_path(standalone), params: { container: { status: "vacio" } }
      expect(standalone.reload).to be_lleno
      patch container_path(record), params: { container: { status: "inventado" } }
      expect(record.reload).to be_activo
    end

    it "shows the status dropdown only in edit for containers with MBL" do
      get edit_container_path(record)
      expect(response.body).to include(I18n.t("containers.form.status_edit_hint"))
      get edit_container_path(create(:container))
      expect(response.body).not_to include(I18n.t("containers.form.status_edit_hint"))
    end

    it "updates and deletes" do
      patch container_path(record), params: { container: { size: 40 } }
      expect(record.reload.size).to eq(40)
      expect { delete container_path(record) }.to change(Container, :count).by(-1)
    end

    it "renders pages without missing translations" do
      [ new_container_path, edit_container_path(record), containers_path, container_path(record) ].each do |path|
        get path
        expect(response.body).not_to include("translation missing", "translation_missing")
      end
    end
  end

  context "as non-admin" do
    before { sign_in create(:user, :cliente) }

    it "cannot create or change the status" do
      expect { post containers_path, params: { container: { number: "MSKU2222222", size: 20, container_type: "standard" } } }.not_to change(Container, :count)
      patch container_path(record), params: { container: { status: "lleno" } }
      expect(record.reload).to be_activo
    end
  end

  it "requires login" do
    get containers_path
    expect(response).to redirect_to(new_user_session_path)
  end
end

RSpec.describe "Contenedores como Seguridad", type: :request do
  before { sign_in create(:user, :seguridad) }

  it "ve el navbar, lista, crea, edita y elimina contenedores sin acceder a MBL" do
    container = create(:container, :with_master_bl)

    get containers_path
    expect(response.body).to include(container.number, "Contenedores")
    expect(response.body).not_to include(%(href="/master_bls"))

    get container_path(container)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(container.master_bl.number)

    post containers_path, params: { container: { number: "ABCD1234567", size: 20, container_type: "standard", status: "lleno", client_id: create(:client).id } }
    expect(Container.find_by(number: "ABCD1234567")).to be_present

    patch container_path(container), params: { container: { size: 40 } }
    expect(container.reload.size).to eq(40)

    expect { delete container_path(container) }.to change(Container, :count).by(-1)
  end

  it "no puede cambiar el estado ni entrar a MBL" do
    container = create(:container, :with_master_bl)
    patch container_path(container), params: { container: { status: "lleno" } }
    expect(container.reload.status).to eq("activo")

    get master_bls_path
    expect(response).not_to have_http_status(:ok)
  end
end

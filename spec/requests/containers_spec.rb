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

    it "creates a record without MBL" do
      expect { post containers_path, params: { container: { number: "msku1234567", size: 40, container_type: "hq", status: "vacio" } } }.to change(Container, :count).by(1)
      expect(Container.last).to have_attributes(number: "MSKU1234567", size: 40, container_type: "hq", status: "vacio", master_bl: nil)
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

    it "does not allow changing status through update" do
      patch container_path(record), params: { container: { status: "entregado" } }
      expect(record.reload).to be_activo
    end

    it "updates and deletes" do
      patch container_path(record), params: { container: { size: 40 } }
      expect(record.reload.size).to eq(40)
      expect { delete container_path(record) }.to change(Container, :count).by(-1)
    end

    it "applies a valid transition" do
      patch transition_container_path(record, event: "llenar")
      expect(record.reload).to be_lleno
      expect(flash[:notice]).to eq(I18n.t("flash.containers.transition"))
    end

    it "rejects transitions for containers without MBL" do
      standalone = create(:container)
      patch transition_container_path(standalone, event: "vaciar")
      expect(standalone.reload).to be_lleno
      expect(flash[:alert]).to eq(I18n.t("flash.containers.invalid_transition"))
    end

    it "rejects an invalid transition" do
      patch transition_container_path(record, event: "entregar")
      expect(record.reload).to be_activo
      expect(flash[:alert]).to eq(I18n.t("flash.containers.invalid_transition"))
    end

    it "rejects unknown events" do
      patch transition_container_path(record, event: "destroy")
      expect(flash[:alert]).to eq(I18n.t("flash.containers.invalid_transition"))
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

    it "cannot create or transition" do
      expect { post containers_path, params: { container: { number: "MSKU2222222", size: 20, container_type: "standard" } } }.not_to change(Container, :count)
      patch transition_container_path(record, event: "llenar")
      expect(record.reload).to be_activo
    end
  end

  it "requires login" do
    get containers_path
    expect(response).to redirect_to(new_user_session_path)
  end
end

require "rails_helper"

RSpec.describe "MasterBls", type: :request do
  let!(:record) { create(:master_bl) }
  let(:client) { create(:client) }

  context "as admin" do
    before { sign_in create(:user, :admin) }

    it "lists records" do
      get master_bls_path
      expect(response.body).to include(record.number, master_bl_path(record))
    end

    it "shows a record" do
      get master_bl_path(record)
      expect(response.body).to include(record.number, record.client.name)
    end

    it "creates a record linked to a client" do
      expect { post master_bls_path, params: { master_bl: { number: "cosu999", client_id: client.id } } }.to change(MasterBl, :count).by(1)
      expect(MasterBl.last).to have_attributes(number: "COSU999", client: client)
      expect(flash[:notice]).to eq(I18n.t("flash.master_bls.create"))
    end

    it "rejects a duplicate number" do
      expect { post master_bls_path, params: { master_bl: { number: record.number, client_id: client.id } } }.not_to change(MasterBl, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "updates a record" do
      patch master_bl_path(record), params: { master_bl: { number: "NUEVO1" } }
      expect(record.reload.number).to eq("NUEVO1")
    end

    it "deletes a record" do
      expect { delete master_bl_path(record) }.to change(MasterBl, :count).by(-1)
    end

    it "lists the containers of the MBL on the detail page" do
      container = create(:container, :with_master_bl, master_bl: record)
      other = create(:container, :with_master_bl)
      get master_bl_path(record)
      expect(response.body).to include(container.number, template_master_bl_path(record), import_master_bl_path(record))
      expect(response.body).not_to include(other.number)
    end

    it "downloads the Excel template" do
      get template_master_bl_path(record)
      expect(response.media_type).to eq(ContainerSpreadsheet::CONTENT_TYPE)
      expect(response.headers["Content-Disposition"]).to include("#{record.number}.xlsx")
    end

    it "imports containers from an Excel file" do
      file = build_xlsx([ [ "MSKU1234567", 20, "Estándar" ], [ "TGHU7654321", 40, "HQ" ] ])
      expect { post import_master_bl_path(record), params: { file: file } }.to change { record.containers.count }.by(2)
      expect(response).to redirect_to(master_bl_path(record))
      expect(flash[:notice]).to eq(I18n.t("flash.master_bls.import", count: 2))
    end

    it "shows row errors and imports nothing when the file is invalid" do
      file = build_xlsx([ [ "MSKU1234567", 20, "HQ" ], [ "MALO", 20, "HQ" ] ])
      expect { post import_master_bl_path(record), params: { file: file } }.not_to change(Container, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Fila 3")
    end

    it "requires a file" do
      post import_master_bl_path(record)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("container_import.errors.no_file"))
    end

    it "renders forms without missing translations" do
      [ new_master_bl_path, edit_master_bl_path(record), master_bls_path ].each do |path|
        get path
        expect(response.body).not_to include("translation missing", "translation_missing")
      end
    end
  end

  context "as non-admin" do
    before { sign_in create(:user, :cliente) }

    it "cannot import or download the template" do
      get template_master_bl_path(record)
      expect(response).not_to have_http_status(:ok)
      expect { post import_master_bl_path(record), params: { file: build_xlsx([ [ "MSKU1234567", 20, "HQ" ] ]) } }.not_to change(Container, :count)
    end

    it "cannot create" do
      expect { post master_bls_path, params: { master_bl: { number: "X1", client_id: client.id } } }.not_to change(MasterBl, :count)
    end
  end

  it "requires login" do
    get master_bls_path
    expect(response).to redirect_to(new_user_session_path)
  end
end

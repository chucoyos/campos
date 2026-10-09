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

    it "renders forms without missing translations" do
      [ new_master_bl_path, edit_master_bl_path(record), master_bls_path ].each do |path|
        get path
        expect(response.body).not_to include("translation missing", "translation_missing")
      end
    end
  end

  context "as non-admin" do
    before { sign_in create(:user, :cliente) }

    it "cannot create" do
      expect { post master_bls_path, params: { master_bl: { number: "X1", client_id: client.id } } }.not_to change(MasterBl, :count)
    end
  end

  it "requires login" do
    get master_bls_path
    expect(response).to redirect_to(new_user_session_path)
  end
end

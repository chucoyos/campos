require "rails_helper"

RSpec.describe "Clients", type: :request do
  let!(:record) { create(:client) }

  context "as admin" do
    before { sign_in create(:user, :admin) }

    it "lists records" do
      get clients_path
      expect(response.body).to include(record.name, client_path(record))
    end

    it "shows a record" do
      get client_path(record)
      expect(response).to have_http_status(:ok)
    end

    it "creates a record" do
      expect { post clients_path, params: { client: { name: "Nuevo" } } }.to change(Client, :count).by(1)
      expect(flash[:notice]).to eq(I18n.t("flash.clients.create"))
    end

    it "rejects a blank name" do
      expect { post clients_path, params: { client: { name: "" } } }.not_to change(Client, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "updates a record" do
      patch client_path(record), params: { client: { name: "Renombrado" } }
      expect(record.reload.name).to eq("Renombrado")
    end

    it "does not delete a client that has MBLs" do
      create(:master_bl, client: record)
      expect { delete client_path(record) }.not_to change(Client, :count)
      expect(response).to redirect_to(client_path(record))
      expect(flash[:alert]).to eq(I18n.t("flash.clients.destroy_restricted"))
    end

    it "deletes a record" do
      expect { delete client_path(record) }.to change(Client, :count).by(-1)
    end

    it "renders forms without missing translations" do
      [ new_client_path, edit_client_path(record) ].each do |path|
        get path
        expect(response.body).not_to include("translation missing", "translation_missing")
      end
    end
  end

  context "as non-admin" do
    before { sign_in create(:user, :cliente) }

    it "cannot create" do
      expect { post clients_path, params: { client: { name: "Nuevo" } } }.not_to change(Client, :count)
    end
  end

  it "requires login" do
    get clients_path
    expect(response).to redirect_to(new_user_session_path)
  end
end

require "rails_helper"

RSpec.describe "Carriers", type: :request do
  let!(:record) { create(:carrier) }

  context "as admin" do
    before { sign_in create(:user, :admin) }

    it "lists records" do
      get carriers_path
      expect(response.body).to include(record.name, carrier_path(record))
    end

    it "shows a record" do
      get carrier_path(record)
      expect(response).to have_http_status(:ok)
    end

    it "creates a record" do
      expect { post carriers_path, params: { carrier: { name: "Nuevo" } } }.to change(Carrier, :count).by(1)
      expect(flash[:notice]).to eq(I18n.t("flash.carriers.create"))
    end

    it "rejects a blank name" do
      expect { post carriers_path, params: { carrier: { name: "" } } }.not_to change(Carrier, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "updates a record" do
      patch carrier_path(record), params: { carrier: { name: "Renombrado" } }
      expect(record.reload.name).to eq("Renombrado")
    end

    it "deletes a record" do
      expect { delete carrier_path(record) }.to change(Carrier, :count).by(-1)
    end

    it "renders forms without missing translations" do
      [ new_carrier_path, edit_carrier_path(record) ].each do |path|
        get path
        expect(response.body).not_to include("translation missing", "translation_missing")
      end
    end
  end

  context "as non-admin" do
    before { sign_in create(:user, :cliente) }

    it "cannot create" do
      expect { post carriers_path, params: { carrier: { name: "Nuevo" } } }.not_to change(Carrier, :count)
    end
  end

  it "requires login" do
    get carriers_path
    expect(response).to redirect_to(new_user_session_path)
  end
end

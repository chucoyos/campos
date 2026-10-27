require 'rails_helper'

RSpec.describe "Homes", type: :request do
  describe "GET /index" do
    it "redirects guests to login" do
      get "/home/index"
      expect(response).to redirect_to(new_user_session_path)
    end

    it "sends admins to the MBL list from the root" do
      sign_in create(:user, :admin)
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include(new_master_bl_path)
    end

    it "shows the welcome page only to accounts without modules" do
      sign_in create(:user, :cliente)
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("home.index.title"))
    end

    it "sends transport users to their assignments" do
      sign_in create(:user, :transporte, carrier: create(:carrier))
      get root_path
      expect(response).to redirect_to(container_assignments_path)
    end

    it "lands clients with a company on their MBLs without welcome text" do
      sign_in create(:user, :cliente, client: create(:client))
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include(I18n.t("home.index.subtitle"))
    end

    it "sends a client-role account that only has a carrier to assignments" do
      sign_in create(:user, :cliente, carrier: create(:carrier))
      get root_path
      expect(response).to redirect_to(container_assignments_path)
    end

    it "sends security to the gate console" do
      sign_in create(:user, :seguridad)
      get root_path
      expect(response).to redirect_to(gate_path)
    end

    it "keeps transport accounts without a carrier on the welcome page" do
      sign_in create(:user, :transporte)
      get root_path
      expect(response).to have_http_status(:success)
    end

    it "returns http success when signed in" do
      sign_in create(:user)
      get "/home/index"
      expect(response).to have_http_status(:success)
    end
  end
end

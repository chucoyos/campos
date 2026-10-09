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

    it "shows the welcome page to non-admins without redirect loops" do
      sign_in create(:user, :cliente)
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include(I18n.t("home.index.title"))
    end

    it "returns http success when signed in" do
      sign_in create(:user)
      get "/home/index"
      expect(response).to have_http_status(:success)
    end
  end
end

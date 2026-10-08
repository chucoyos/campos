require 'rails_helper'

RSpec.describe "Homes", type: :request do
  describe "GET /index" do
    it "redirects guests to login" do
      get "/home/index"
      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns http success when signed in" do
      sign_in create(:user)
      get "/home/index"
      expect(response).to have_http_status(:success)
    end
  end
end

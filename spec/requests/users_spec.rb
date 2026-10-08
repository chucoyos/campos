require "rails_helper"

RSpec.describe "Users", type: :request do
  let(:params) { { user: { email: "nuevo@example.com", role: "grua", password: "password123", password_confirmation: "password123" } } }

  context "as admin" do
    before { sign_in create(:user, :admin) }

    it "creates a user with the chosen role" do
      expect { post users_path, params: params }.to change(User, :count).by(1)
      expect(User.find_by(email: "nuevo@example.com").role).to eq("grua")
    end
  end

  context "as non-admin" do
    before { sign_in create(:user, :cliente) }

    it "cannot create users" do
      expect { post users_path, params: params }.not_to change(User, :count)
    end
  end

  it "requires login" do
    get users_path
    expect(response).to redirect_to(new_user_session_path)
  end
end

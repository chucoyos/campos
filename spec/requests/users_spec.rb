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

  context "as admin managing users" do
    let(:admin) { create(:user, :admin) }
    let!(:other) { create(:user, :cliente) }

    before { sign_in admin }

    it "lists users with edit and delete actions" do
      get users_path
      expect(response.body).to include(edit_user_path(other), "Eliminar")
    end

    it "shows cancel and delete on the edit page" do
      get edit_user_path(other)
      expect(response.body).to include("Cancelar", "Eliminar")
    end

    it "shows a user" do
      get user_path(other)
      expect(response.body).to include(other.email, "Editar", "Eliminar")
    end

    it "lists view links" do
      get users_path
      expect(response.body).to include(user_path(other))
    end

    it "updates a user" do
      patch user_path(other), params: { user: { role: "seguridad" } }
      expect(other.reload.role).to eq("seguridad")
    end

    it "deletes a user" do
      expect { delete user_path(other) }.to change(User, :count).by(-1)
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

require "rails_helper"

RSpec.describe "i18n", type: :request do
  it "uses Spanish as the default locale" do
    expect(I18n.default_locale).to eq(:es)
  end

  it "translates active record attributes" do
    expect(User.human_attribute_name(:email)).to eq("Correo electrónico")
  end

  it "shows Spanish flash messages for users" do
    sign_in create(:user, :admin)
    post users_path, params: { user: { email: "a@example.com", role: "grua", password: "password123", password_confirmation: "password123" } }
    expect(flash[:notice]).to eq("Usuario creado.")
  end

  it "shows the Devise sign out flash in Spanish" do
    sign_in create(:user)
    delete destroy_user_session_path
    expect(flash[:notice]).to eq("Sesión finalizada.")
  end

  it "shows the Devise failed login flash in Spanish" do
    post user_session_path, params: { user: { email: "x@example.com", password: "bad" } }
    expect(flash[:alert]).to match(/inválido|Email o contraseña/i)
  end

  it "renders views without missing translations" do
    admin = create(:user, :admin)
    other = create(:user, :cliente)
    sign_in admin
    [ users_path, new_user_path, user_path(other), edit_user_path(other), root_path ].each do |path|
      get path
      expect(response.body).not_to include("translation missing", "translation_missing")
    end
    expect(response.body).to include("Cerrar sesión")
  end

  it "renders guest views without missing translations" do
    [ new_user_session_path, new_user_password_path ].each do |path|
      get path
      expect(response.body).not_to include("translation missing", "translation_missing")
    end
  end
end

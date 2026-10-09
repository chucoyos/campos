require "rails_helper"

RSpec.describe "Sessions", type: :request do
  it "renders the styled login page" do
    get new_user_session_path
    expect(response.body).to include("Iniciar sesión")
  end

  it "shows the navbar with a logout button when signed in" do
    sign_in create(:user)
    get root_path
    expect(response.body).to include("logout")
  end

  it "renders the hamburger menu button" do
    sign_in create(:user)
    get root_path
    expect(response.body).to include("navbar#toggle", "Abrir menú")
  end

  it "signs out" do
    sign_in create(:user)
    delete destroy_user_session_path
    expect(response).to redirect_to(root_path)
  end
end

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

  it "groups clients, carriers and users under a Catálogos dropdown for admins" do
    sign_in create(:user, :admin)
    get root_path
    expect(response.body).to include('data-controller="dropdown"', "Catálogos", clients_path, carriers_path, users_path)
    expect(response.body).not_to include("Inicio")
  end

  it "hides the Catálogos dropdown from non-admins" do
    sign_in create(:user, :cliente)
    get root_path
    expect(response.body).not_to include("Catálogos")
  end

  it "renders the hamburger menu button" do
    sign_in create(:user)
    get root_path
    expect(response.body).to include("navbar#toggle", "Abrir menú")
  end

  it "renders flash messages as dismissible toasts" do
    sign_in create(:user, :cliente)
    get users_path
    follow_redirect!
    expect(response.body).to include('data-controller="flash"', "Cerrar notificación")
  end

  it "signs out" do
    sign_in create(:user)
    delete destroy_user_session_path
    expect(response).to redirect_to(root_path)
  end
end

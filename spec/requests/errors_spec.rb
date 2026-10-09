require "rails_helper"

RSpec.describe "Errors", type: :request do
  # Simula producción: sin la página de depuración de Rails.
  around do |example|
    env_config = Rails.application.env_config
    original = env_config.slice("action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions")
    env_config["action_dispatch.show_exceptions"] = :all
    env_config["action_dispatch.show_detailed_exceptions"] = false
    example.run
    env_config.merge!(original)
  end

  it "shows the 404 page for unknown routes, even to guests" do
    get "/esta-ruta-no-existe"
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include(I18n.t("errors.404.title"), "Ir al inicio")
  end

  it "shows the 404 page for records that do not exist" do
    sign_in create(:user, :admin)
    get master_bl_path(0)
    expect(response).to have_http_status(:not_found)
    expect(response.body).to include(I18n.t("errors.404.title"))
  end

  it "answers non-HTML requests with only the status" do
    get "/no-existe.json"
    expect(response).to have_http_status(:not_found)
    expect(response.body).to be_blank
  end

  {
    400 => [ ActionController::BadRequest, :bad_request ],
    422 => [ ActionController::InvalidAuthenticityToken, :unprocessable_content ],
    500 => [ StandardError, :internal_server_error ]
  }.each do |code, (error, status)|
    it "renders the #{code} page when an action raises #{error}" do
      sign_in create(:user, :admin)
      allow_any_instance_of(MasterBlsController).to receive(:index).and_raise(error)
      get master_bls_path
      expect(response).to have_http_status(status)
      expect(response.body).to include(I18n.t("errors.#{code}.title"))
    end
  end

  it "has translations for every error code" do
    ErrorsController::CODES.each do |code|
      expect(I18n.exists?("errors.#{code}.title")).to be(true)
      expect(I18n.exists?("errors.#{code}.message")).to be(true)
    end
  end
end

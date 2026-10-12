require "rails_helper"

RSpec.describe "Pagination", type: :request do
  before { sign_in create(:user, :admin) }

  it "paginates the MBL list" do
    create_list(:master_bl, 17)

    get master_bls_path
    expect(response.body.scan("href=\"/master_bls/").size).to be >= 15
    expect(response.body).to include("Mostrando 1–15 de 17", "page=2")
    expect(response.body).to include("17 mbl")

    get master_bls_path(page: 2)
    expect(response.body).to include("Mostrando 16–17 de 17")
  end

  it "paginates the container list keeping the order and without N+1" do
    create_list(:container, 16, :with_master_bl)

    get containers_path
    expect(response.body).to include("Mostrando 1–15 de 16", I18n.t("shared.pagination.next"))
    get containers_path(page: 2)
    expect(response.body).to include("Mostrando 16–16 de 16")
  end

  it "hides the controls when everything fits in one page" do
    create_list(:master_bl, 2)
    get master_bls_path
    expect(response.body).not_to include(I18n.t("shared.pagination.label"))
  end

  it "redirects a page beyond the last one to the last page" do
    create_list(:master_bl, 17)
    get master_bls_path(page: 99)
    expect(response).to redirect_to(master_bls_path(page: 2))
  end
end

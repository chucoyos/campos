require "rails_helper"

RSpec.describe "Pagination", type: :request do
  before { sign_in create(:user, :admin) }

  it "paginates the MBL list" do
    create_list(:master_bl, 12)

    get master_bls_path
    expect(response.body).to include("Mostrando 1–10 de 12", "page=2", "12 mbl")

    get master_bls_path(page: 2)
    expect(response.body).to include("Mostrando 11–12 de 12")
  end

  it "paginates the container list keeping the order and without N+1" do
    create_list(:container, 11, :with_master_bl)

    get containers_path
    expect(response.body).to include("Mostrando 1–10 de 11", I18n.t("shared.pagination.next"))
    get containers_path(page: 2)
    expect(response.body).to include("Mostrando 11–11 de 11")
  end

  it "defaults to 10 per page and offers 10, 25, 50 and 100" do
    create_list(:master_bl, 11)
    get master_bls_path
    expect(response.body).to include("Mostrando 1–10 de 11", 'data-controller="per-page"')
    [ 10, 25, 50, 100 ].each { |n| expect(response.body).to include("<option") && include("value=\"#{n}\"") }
  end

  it "applies the per_page option and keeps it across pages" do
    create_list(:master_bl, 30)
    get master_bls_path(per_page: 25)
    expect(response.body).to include("Mostrando 1–25 de 30", "per_page=25")
    expect(response.body).to include('<option selected="selected" value="25">')
  end

  it "ignores unsupported per_page values" do
    create_list(:master_bl, 30)
    get master_bls_path(per_page: 7)
    expect(response.body).to include("Mostrando 1–10 de 30")
    get master_bls_path(per_page: "abc")
    expect(response.body).to include("Mostrando 1–10 de 30")
  end

  it "keeps the selector available when the chosen size exceeds the total" do
    create_list(:master_bl, 12)
    get master_bls_path(per_page: 100)
    expect(response.body).to include("Mostrando 1–12 de 12", 'data-controller="per-page"')
  end

  it "paginates clients, carriers and users too" do
    create_list(:client, 11)
    create_list(:carrier, 11)
    create_list(:user, 11, :cliente)
    [ clients_path, carriers_path, users_path ].each do |path|
      get path
      expect(response.body).to include("Mostrando 1–10 de 1"), path
    end
  end

  it "hides the controls when there are 10 records or fewer" do
    create_list(:master_bl, 10)
    get master_bls_path
    expect(response.body).not_to include(I18n.t("shared.pagination.label"))
  end

  it "redirects a page beyond the last one to the last page" do
    create_list(:master_bl, 17)
    get master_bls_path(page: 99)
    expect(response).to redirect_to(master_bls_path(page: 2))
  end
end

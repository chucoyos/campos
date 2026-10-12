require "rails_helper"

# Bullet.raise = true en test: cualquier N+1 en estas páginas hace fallar el spec.
RSpec.describe "N+1 queries", type: :request do
  before do
    sign_in create(:user, :admin)
    master_bls = create_list(:master_bl, 3)
    master_bls.each { |master_bl| create_list(:container, 2, :with_master_bl, master_bl: master_bl) }
    create_list(:container, 2)
  end

  it "does not trigger N+1 in the MBL list" do
    get master_bls_path
    expect(response).to have_http_status(:ok)
  end

  it "does not trigger N+1 in the container list" do
    get containers_path
    expect(response).to have_http_status(:ok)
  end

  it "does not trigger N+1 in the MBL detail" do
    get master_bl_path(MasterBl.first)
    expect(response).to have_http_status(:ok)
  end

  it "does not trigger N+1 in the other lists" do
    create_list(:carrier, 3)
    [ clients_path, carriers_path, users_path ].each do |path|
      get path
      expect(response).to have_http_status(:ok)
    end
  end
end

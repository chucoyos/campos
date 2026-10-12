require "rails_helper"

RSpec.describe "Filtros de listados", type: :request do
  before { sign_in create(:user, :admin) }

  it "filtra MBL por número y cliente y muestra los filtros aplicados" do
    client = create(:client, name: "ACME")
    create(:master_bl, number: "MBL-AAA", client: client)
    create(:master_bl, number: "MBL-BBB")

    get master_bls_path(q: "aaa", client_id: client.id)

    expect(response.body).to include("MBL-AAA")
    expect(response.body).not_to include("MBL-BBB")
    expect(response.body).to include("Filtros aplicados", "ACME")
    expect(response.body).to include("1 mbl")
  end

  it "filtra contenedores por estado, tamaño, tipo y MBL" do
    create(:container, :with_master_bl, number: "ABCD1234567", size: 40)
    create(:container, number: "WXYZ7654321", status: "lleno", size: 20)

    get containers_path(master_bl: MasterBl.first.number.downcase)
    expect(response.body).to include("ABCD1234567")
    expect(response.body).not_to include("WXYZ7654321")

    get containers_path(status: "activo", size: "40")
    expect(response.body).to include("ABCD1234567")
    expect(response.body).not_to include("WXYZ7654321")
    expect(response.body).to include("Filtros aplicados")
  end

  it "filtra clientes, transportistas y usuarios" do
    create(:client, name: "Naviera Uno")
    create(:client, name: "Otra")
    create(:carrier, name: "Transp Uno")
    create(:carrier, name: "Otro")
    create(:user, :grua, email: "grua@example.com")

    get clients_path(q: "naviera")
    expect(response.body).to include("Naviera Uno")
    expect(response.body).not_to include("Otra")

    get carriers_path(q: "transp")
    expect(response.body).to include("Transp Uno")

    get users_path(role: "grua")
    expect(response.body).to include("grua@example.com")
  end

  it "ignora valores inválidos y escapa comodines" do
    create(:client, name: "Cien")
    get clients_path(q: "%")
    expect(response.body).not_to include("Cien</td>")

    get containers_path(status: "inexistente")
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Filtros aplicados")
  end

  it "conserva los filtros al cambiar de página y el tamaño de página" do
    12.times { |i| create(:client, name: "Norte #{i}") }
    get clients_path(q: "norte")
    expect(response.body).to include("page=2", "q=norte")
    expect(response.body).to include('name="q"')
  end
end

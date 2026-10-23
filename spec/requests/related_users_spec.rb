require "rails_helper"

RSpec.describe "Usuarios relacionados", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:client) { create(:client) }
  let(:carrier) { create(:carrier) }

  before { sign_in admin }

  it "crea un usuario cliente vinculado a un cliente" do
    post users_path, params: { user: { email: "c@example.com", role: "cliente", client_id: client.id,
                                       password: "password123", password_confirmation: "password123" } }

    expect(User.find_by(email: "c@example.com").client).to eq(client)
  end

  it "crea una cuenta dual vinculada a cliente y transportista y la muestra en el listado" do
    post users_path, params: { user: { email: "d@example.com", role: "transporte", client_id: client.id, carrier_id: carrier.id,
                                       password: "password123", password_confirmation: "password123" } }

    user = User.find_by(email: "d@example.com")
    expect([ user.client, user.carrier ]).to eq([ client, carrier ])
    get users_path
    expect(response.body).to include(client.name, carrier.name)
  end

  it "ofrece ambos selectores en el formulario de usuario" do
    get new_user_path
    expect(response.body).to include("user_client_id", "user_carrier_id")
  end

  it "edita el transportista de un usuario" do
    user = create(:user, :transporte)
    patch user_path(user), params: { user: { carrier_id: carrier.id } }
    expect(user.reload.carrier).to eq(carrier)
  end

  it "precarga el rol y el cliente desde el detalle" do
    get new_user_path(role: "cliente", client_id: client.id)
    expect(response.body).to match(/<option[^>]*selected[^>]*value="#{client.id}"|<option[^>]*value="#{client.id}"[^>]*selected/)
  end

  it "lista los usuarios relacionados en el detalle del cliente" do
    user = create(:user, :cliente, client: client)
    get client_path(client)
    expect(response.body).to include(user.email)
  end

  it "muestra la entidad de cada usuario en el listado" do
    create(:user, :cliente, client: create(:client, name: "Acme SA"))
    create(:user, :transporte, carrier: create(:carrier, name: "Fletes MX"))

    get users_path

    expect(response.body).to include("Acme SA").and include("Fletes MX")
  end

  it "vincula y desvincula usuarios de un transportista" do
    user = create(:user, :transporte)

    post link_user_carrier_path(carrier), params: { user_id: user.id }
    expect(user.reload.carrier).to eq(carrier)

    delete unlink_user_carrier_path(carrier, user_id: user.id)
    expect(user.reload.carrier).to be_nil
  end

  it "no vincula usuarios de otro rol" do
    user = create(:user, :grua)
    post link_user_client_path(client), params: { user_id: user.id }
    expect(user.reload.client_id).to be_nil
  end

  it "no permite administrar vínculos a usuarios sin permiso" do
    sign_in create(:user, :seguridad)
    user = create(:user, :cliente)
    post link_user_client_path(client), params: { user_id: user.id }
    expect(user.reload.client).to be_nil
  end
end

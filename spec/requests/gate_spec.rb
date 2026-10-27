require "rails_helper"

RSpec.describe "Garita", type: :request do
  let(:user) { create(:user, :seguridad) }
  let(:container) { create(:container, client: create(:client)) }
  let(:block) { create(:yard_block, bays: 4, rows: 1, levels: 1) }
  let!(:slot) { create(:yard_slot, yard_block: block, bay: 1, row: "A", level: 1) }
  let(:pass) { create(:movement_pass, :standalone, container: container) }
  let(:png) { Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==") }

  before { sign_in user }

  it "muestra la consola y permite validar un pase vigente" do
    pass
    get gate_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Escanea el QR", "qr-camera", 'data-turbo="false"')

    post scan_gate_pass_path, params: { token: pass.token }
    expect(response).to redirect_to(gate_movement_path(pass))

    get gate_movement_path(pass)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(container.number, slot.code, "yard-slot-search", "Evidencia fotográfica")
  end

  it "abre el detalle del pase desde el enlace escaneado por la cámara nativa" do
    get gate_pass_path(pass.token)

    expect(response).to redirect_to(gate_movement_path(pass))

    follow_redirect!
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(container.number, "Evidencia fotográfica")
  end

  it "rechaza un enlace QR desconocido y vuelve a Garita" do
    get gate_pass_path("unknown-token")

    expect(response).to redirect_to(gate_path)
    follow_redirect!
    expect(response.body).to include(I18n.t("gate.errors.pass_not_found"))
  end

  it "vence y rechaza el pase cuando se abre un enlace QR vencido" do
    pass.update_columns(expires_at: 1.minute.ago)

    get gate_pass_path(pass.token)

    expect(response).to redirect_to(gate_path)
    expect(pass.reload).to be_vencido
  end

  it "rechaza un token desconocido con un mensaje visible" do
    post scan_gate_pass_path, params: { token: "unknown-token" }

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include(I18n.t("gate.errors.pass_not_found"))
  end

  it "requiere iniciar sesión y conserva el enlace QR como destino" do
    sign_out user

    get gate_pass_path(pass.token)

    expect(response).to redirect_to(new_user_session_path)
    expect(session["user_return_to"]).to eq(gate_pass_path(pass.token))
  end

  it "completa el movimiento y no permite reutilizar el pase" do
    pass
    expect {
      post complete_gate_movement_path(pass), params: { yard_slot_id: slot.id }
    }.to change(ContainerMovement, :count).by(1)

    expect(response).to redirect_to(container_path(container))
    expect(pass.reload).to be_completado

    post scan_gate_pass_path, params: { token: pass.token }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include(I18n.t("gate.errors.pass_unusable"))
  end

  it "transfiere las fotos del pase al historial al confirmar el movimiento" do
    photo = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(png), filename: "evidencia.png", content_type: "image/png"
    )
    post gate_movement_photos_path(pass), params: { photos: [ photo.signed_id ] }

    expect(response).to redirect_to(gate_movement_path(pass))
    expect(pass.reload.photos.count).to eq(1)

    expect {
      post complete_gate_movement_path(pass), params: { yard_slot_id: slot.id }
    }.to change(ContainerMovement, :count).by(1)

    movement = ContainerMovement.last
    expect(movement.photos.count).to eq(1)
    expect(pass.reload.photos.count).to eq(0)

    get container_path(container)
    expect(response.body).to include("Historial de movimientos", "movement_photos_#{movement.id}")
    movement_details = response.body.match(/<details data-movement-id="#{movement.id}"[^>]*>/).to_s
    expect(movement_details).not_to match(/\sopen(?:\s|=|>)/)

    get container_movement_photos_path(container, movement), headers: { "Turbo-Frame" => "movement_photos_#{movement.id}" }
    expect(response.body).to include('turbo-frame id="movement_photos_', "evidencia.png")
  end

  it "rechaza evidencia que no es una imagen" do
    document = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF"), filename: "evidencia.pdf", content_type: "application/pdf"
    )

    post gate_movement_photos_path(pass), params: { photos: [ document.signed_id ] }

    expect(pass.reload.photos.count).to eq(0)
    expect(flash[:alert] || response.body).to include("debe ser una imagen")
  end

  it "no permite operar la consola a clientes ni transportistas" do
    pass
    sign_out user
    sign_in create(:user, :transporte, carrier: create(:carrier))

    get gate_path

    expect(response).to redirect_to(root_path)

    get gate_pass_path(pass.token)

    expect(response).to redirect_to(root_path)
  end
end

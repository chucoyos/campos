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
    upload_button = Nokogiri::HTML(response.body).at_css('button[data-photo-upload-target="submit"]')
    expect(upload_button["disabled"]).to be_present
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

  it "acepta la URL completa del QR como token escaneado" do
    post scan_gate_pass_path, params: { token: gate_pass_url(pass.token) }

    expect(response).to redirect_to(gate_movement_path(pass))
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
    }.to change(WorkOrder, :count).by(1)

    expect(response).to redirect_to(gate_path)
    expect(pass.reload).to be_vigente
    expect(pass.entered_at).to be_present
    expect(container.reload.current_yard_slot).to be_nil

    CraneTaskService.complete(work_order: WorkOrder.find_by!(movement_pass: pass), user: create(:user, :grua))
    post scan_gate_pass_path, params: { token: pass.token }
    expect(response).to redirect_to(gate_movement_path(pass))
    expect(response.body).not_to be_present

    post complete_gate_movement_path(pass)
    expect(response).to redirect_to(gate_path)
    expect(pass.reload).to be_completado

    post scan_gate_pass_path, params: { token: pass.token }
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include(I18n.t("gate.errors.pass_unusable"))
  end

  it "registra la salida solo después de la carga física y del segundo escaneo" do
    container.update!(current_yard_slot: slot)
    output_pass = create(:movement_pass, :standalone, container:, movement_type: "salida", load_status: nil)

    post scan_gate_pass_path, params: { token: output_pass.token }
    expect(response).to redirect_to(gate_movement_path(output_pass))

    post complete_gate_movement_path(output_pass)
    expect(response).to redirect_to(gate_path)
    expect(output_pass.reload).to have_attributes(status: "vigente")
    expect(output_pass.entered_at).to be_present
    expect(output_pass.movement).to be_nil

    order = WorkOrder.find_by!(movement_pass: output_pass)
    CraneTaskService.complete(work_order: order, user: create(:user, :grua))
    expect(output_pass.reload.movement).to be_present

    post scan_gate_pass_path, params: { token: output_pass.token }
    expect(response).to redirect_to(gate_movement_path(output_pass))
    exit_scan_time = output_pass.reload.exit_scanned_at
    expect(exit_scan_time).to be_present

    post scan_gate_pass_path, params: { token: output_pass.token }
    expect(output_pass.reload.exit_scanned_at).to eq(exit_scan_time)

    post complete_gate_movement_path(output_pass)
    expect(response).to redirect_to(gate_path)
    expect(output_pass.reload).to be_completado
    expect(output_pass.entered_at).to be_present
    expect(container.reload.current_yard_slot).to be_nil
  end

  it "permite fotos opcionales de salida en el segundo escaneo, adjuntas al movimiento" do
    container.update!(current_yard_slot: slot)
    output_pass = create(:movement_pass, :standalone, container:, movement_type: "salida", load_status: nil)
    png = -> { fixture_file_upload(Rails.root.join("public/icon.png"), "image/png") }

    post scan_gate_pass_path, params: { token: output_pass.token }
    post complete_gate_movement_path(output_pass)
    CraneTaskService.complete(work_order: WorkOrder.find_by!(movement_pass: output_pass), user: create(:user, :grua))
    movement = output_pass.reload.movement

    post gate_movement_exit_photos_path(output_pass), params: { photos: [ png.call ] }
    expect(movement.reload.exit_photos.count).to eq(0)

    post scan_gate_pass_path, params: { token: output_pass.token }
    get gate_movement_path(output_pass)
    expect(response.body).to include(I18n.t("gate.show.exit_photos_title"))

    post gate_movement_exit_photos_path(output_pass), params: { photos: [ png.call, png.call ] }
    expect(movement.reload.exit_photos.count).to eq(2)
    expect(movement.photos.count).to eq(0)

    delete remove_gate_movement_exit_photo_path(output_pass, photo_id: movement.exit_photos_attachments.first.id)
    expect(movement.reload.exit_photos_attachments.count).to eq(1)

    post complete_gate_movement_path(output_pass)
    expect(output_pass.reload).to be_completado
    expect(movement.reload.exit_photos.count).to eq(1)

    post gate_movement_exit_photos_path(output_pass), params: { photos: [ png.call ] }
    expect(movement.reload.exit_photos.count).to eq(1)
  end

  it "transfiere las fotos del pase al historial al confirmar el movimiento" do
    photo = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(png), filename: "evidencia.png", content_type: "image/png"
    )
    post gate_movement_photos_path(pass), params: { photos: [ photo.signed_id ] }

    expect(response).to redirect_to(gate_movement_path(pass))
    expect(pass.reload.photos.count).to eq(1)

    post complete_gate_movement_path(pass), params: { yard_slot_id: slot.id }
    expect(pass.reload.photos.count).to eq(1)

    expect {
      CraneTaskService.complete(work_order: WorkOrder.last, user: create(:user, :grua))
    }.to change(ContainerMovement, :count).by(1)

    movement = ContainerMovement.last
    expect(movement.photos.count).to eq(1)
    expect(pass.reload.photos.count).to eq(0)

    post scan_gate_pass_path, params: { token: pass.token }
    post complete_gate_movement_path(pass)
    expect(pass.reload).to be_completado

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

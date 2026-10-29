require "rails_helper"

RSpec.describe "Fotografías del contenedor", type: :request do
  let(:container) { create(:container, :with_master_bl) }
  let(:png) { Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==") }

  def blob(filename: "foto.png", content_type: "image/png", data: png)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(data), filename: filename, content_type: content_type)
  end

  let(:user) { create(:user, :admin) }

  before { sign_in user }

  it "muestra las tres secciones colapsadas con carga diferida" do
    get container_path(container)

    expect(response.body).to include("Apertura", "Desconsolidación", "Vacío")
    main = response.body[/<main.*<\/main>/m]
    expect(main.scan(/<details[^>]*>/).none? { |tag| tag.include?("open") }).to be(true)
    expect(response.body.scan('loading="lazy"').size).to eq(3)
    expect(response.body).to include("/containers/#{container.id}/photos?section=opening")
    expect(response.body).not_to include("foto.png")

    upload_buttons = Nokogiri::HTML(response.body).css('button[data-photo-upload-target="submit"]')
    expect(upload_buttons.size).to eq(3)
    expect(upload_buttons.map { |button| button["disabled"] }).to all(be_present)
  end

  it "sube fotos directo (firmadas) y las lista en el frame de la sección" do
    post upload_photos_container_path(container, section: "opening"), params: { photos: [ blob.signed_id, blob(filename: "otra.png").signed_id ] }

    expect(response).to redirect_to(container_path(container))
    expect(container.reload.opening_photos.count).to eq(2)
    expect(container.deconsolidation_photos.count).to eq(0)

    get photos_container_path(container, section: "opening"), headers: { "Turbo-Frame" => "photos_opening" }
    expect(response.body).to include('turbo-frame id="photos_opening"', "foto.png", "otra.png")
  end

  it "rechaza archivos que no son imágenes" do
    post upload_photos_container_path(container, section: "empty"), params: { photos: [ blob(filename: "a.pdf", content_type: "application/pdf", data: "%PDF").signed_id ] }

    expect(container.reload.empty_photos.count).to eq(0)
    expect(flash[:alert]).to include("debe ser una imagen")
  end

  it "ignora firmas inválidas y secciones desconocidas" do
    post upload_photos_container_path(container, section: "opening"), params: { photos: [ "basura" ] }
    expect(flash[:alert]).to eq("No se pudieron adjuntar las fotografías. Inténtalo de nuevo.")

    get photos_container_path(container, section: "otra")
    expect(response).to have_http_status(:not_found)
  end

  it "elimina una foto" do
    container.deconsolidation_photos.attach(blob)
    photo = container.deconsolidation_photos.first

    delete remove_photo_container_path(container, photo_id: photo.id)

    expect(response).to redirect_to(container_path(container))
    expect(container.reload.deconsolidation_photos.count).to eq(0)
  end

  it "elimina todas las fotos de una sección sin tocar las demás" do
    container.opening_photos.attach(blob)
    container.empty_photos.attach(blob)

    delete remove_photos_container_path(container, section: "opening")

    expect(response).to redirect_to(container_path(container))
    expect(container.reload.opening_photos.count).to eq(0)
    expect(container.empty_photos.count).to eq(1)
  end

  it "encola el ZIP de una sección y muestra el estado de espera" do
    container.opening_photos.attach(blob)

    expect { post zip_photos_container_path(container, section: "opening"), as: :turbo_stream }
      .to have_enqueued_job(ContainerPhotosZipJob).with(container.id, "opening", user.id, hash_including(host: "www.example.com"))
    expect(response.body).to include("zip_opening").and include("turbo-stream")
  end

  it "muestra el enlace del ZIP vigente al volver a la vista" do
    container.opening_photos.attach(blob)
    ContainerPhotosZipJob.perform_now(container.id, "opening", user.id)

    get container_path(container)

    expect(response.body).to include(I18n.t("containers.photos.zip.ready"))
  end

  it "no muestra el ZIP si se agregaron fotos después de generarlo" do
    container.opening_photos.attach(blob)
    ContainerPhotosZipJob.perform_now(container.id, "opening", user.id)
    ActiveStorage::Attachment.where(record: container).update_all(created_at: 1.minute.from_now)

    get container_path(container)

    expect(response.body).not_to include(I18n.t("containers.photos.zip.ready"))
  end

  it "redirige si la sección no tiene fotos para el ZIP" do
    post zip_photos_container_path(container, section: "opening")
    expect(response).to redirect_to(container_path(container))
  end

  it "no permite eliminar fotos de otro contenedor" do
    other = create(:container)
    other.opening_photos.attach(blob)

    expect { delete remove_photo_container_path(container, photo_id: other.opening_photos.first.id) }
      .not_to change { other.opening_photos.count }
  end

  it "permite a Seguridad ver el contenedor y gestionar fotos, sin cambiar estado" do
    sign_in create(:user, :seguridad)

    get container_path(container)
    expect(response).to have_http_status(:ok)

    post upload_photos_container_path(container, section: "opening"), params: { photos: [ blob.signed_id ] }
    expect(container.reload.opening_photos.count).to eq(1)

    delete remove_photo_container_path(container, photo_id: container.opening_photos.first.id)
    expect(container.reload.opening_photos.count).to eq(0)

    get edit_container_path(container)
    expect(response).to have_http_status(:ok)
  end

  it "no permite a usuarios sin permiso" do
    sign_in create(:user, :cliente)
    post upload_photos_container_path(container, section: "opening"), params: { photos: [ blob.signed_id ] }
    expect(container.reload.opening_photos.count).to eq(0)
  end
end

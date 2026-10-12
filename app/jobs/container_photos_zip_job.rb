class ContainerPhotosZipJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  LINK_TTL = 1.hour
  BROADCAST_INTERVAL = 0.5 # segundos entre actualizaciones de progreso

  def perform(container_id, section, user_id, url_options = {})
    container = Container.find(container_id)
    return unless Container::PHOTO_SECTIONS.include?(section)

    # Solo el servicio Disk (dev/test) necesita host y puerto; S3 firma la URL por sí mismo.
    ActiveStorage::Current.url_options = url_options.symbolize_keys.presence || { host: "localhost", port: 3000 }
    @container = container
    @section = section
    @stream = [ "container_zip", container.id, user_id, section ]

    photos = container.public_send(:"#{section}_photos_attachments").includes(:blob).order(:id).to_a
    return broadcast(:failed) if photos.empty?

    blob = build_zip(photos)
    # El ZIP es temporal: el enlace y el archivo expiran juntos.
    ActiveStorage::PurgeJob.set(wait: LINK_TTL).perform_later(blob)
    broadcast(:ready, url: blob.url(expires_in: LINK_TTL, disposition: :attachment, filename: blob.filename))
  rescue StandardError => e
    Rails.logger.error("ContainerPhotosZipJob: #{e.class}: #{e.message}")
    broadcast(:failed) if @stream
  end

  private

  def build_zip(photos)
    zip = Tempfile.new([ "fotos", ".zip" ])
    last_broadcast = 0.0
    Zip::OutputStream.open(zip.path) do |out|
      photos.each_with_index do |photo, index|
        # Las imágenes ya están comprimidas: se empaquetan sin recomprimir.
        out.put_next_entry(format("%03d_%s", index + 1, photo.filename.sanitized), nil, nil, Zip::Entry::STORED)
        photo.blob.download { |chunk| out.write(chunk) }

        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        next unless now - last_broadcast >= BROADCAST_INTERVAL

        last_broadcast = now
        broadcast(:working, done: index + 1, total: photos.size)
      end
    end

    name = "#{@container.number}_#{I18n.t("containers.photos.#{@section}").parameterize}.zip"
    zip.rewind
    ActiveStorage::Blob.create_and_upload!(io: zip, filename: name, content_type: "application/zip")
  ensure
    zip&.close!
  end

  def broadcast(state, **locals)
    Turbo::StreamsChannel.broadcast_replace_to(
      *@stream,
      target: ActionView::RecordIdentifier.dom_id(@container, "zip_#{@section}"),
      partial: "containers/zip_status",
      locals: { container: @container, section: @section, state: state, **locals }
    )
  end
end

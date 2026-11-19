class CargoDispatchTripPhotosZipJob < ContainerPhotosZipJob
  def perform(trip_id, user_id, url_options = {})
    @trip = CargoDispatchTrip.find(trip_id)
    @stream = [ "cargo_dispatch_trip_zip", @trip.id, user_id ]
    ActiveStorage::Current.url_options = url_options.symbolize_keys.presence || { host: "localhost", port: 3000 }
    photos = @trip.exit_photos_attachments.includes(:blob).order(:id).to_a
    return broadcast(:failed) if photos.empty?

    blob = build_zip(photos)
    ActiveStorage::PurgeJob.set(wait: LINK_TTL).perform_later(blob)
    return broadcast(:failed) unless @trip.exit_photos_attachments.order(:id).pluck(:id) == photos.map(&:id)

    broadcast(:ready, url: blob.url(expires_in: LINK_TTL, disposition: :attachment, filename: blob.filename))
  rescue StandardError => e
    Rails.logger.error("CargoDispatchTripPhotosZipJob: #{e.class}: #{e.message}")
    broadcast(:failed) if @stream
  end

  private

  def zip_filename(photos)
    @trip.exit_photos_zip_name(photos)
  end

  def broadcast(state, **locals)
    target = ActionView::RecordIdentifier.dom_id(@trip, "zip_exit_photos")
    Turbo::StreamsChannel.broadcast_replace_to(
      *@stream, target: target, partial: "containers/zip_status",
      locals: { record: @trip, target: target,
        zip_path: Rails.application.routes.url_helpers.zip_exit_photos_cargo_dispatch_trip_path(@trip), state: state, **locals }
    )
  end
end

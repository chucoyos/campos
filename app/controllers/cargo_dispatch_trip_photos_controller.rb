class CargoDispatchTripPhotosController < ApplicationController
  include ActiveStorage::SetCurrent

  before_action :load_trip

  def index
    authorize @trip, :exit_photos?
    @photos = @trip.exit_photos_attachments.includes(:blob).order(:id)
  end

  def show
    authorize @trip, :exit_photos?
    photo = @trip.exit_photos_attachments.includes(:blob).find(params[:photo_id])
    response.headers["X-Content-Type-Options"] = "nosniff"
    send_data photo.blob.download, type: photo.blob.content_type, disposition: "inline"
  end

  def create
    authorize @trip, :manage_exit_photos?
    files = Array(params[:photos]).compact_blank
    return redirect_to @trip, alert: t("flash.containers.photos_missing") if files.empty?
    if files.size > Container::MAX_PHOTOS_PER_UPLOAD
      return redirect_to @trip, alert: t("containers.photos.too_many", max: Container::MAX_PHOTOS_PER_UPLOAD)
    end

    files = files.map { |file| file.is_a?(String) ? ActiveStorage::Blob.find_signed!(file) : file }
    unless files.all? { |file| valid_photo?(file) }
      return redirect_to @trip, alert: t("flash.containers.photos_invalid")
    end

    @trip.with_lock do
      if @trip.exit_photos_attachments.count + files.size > Container::MAX_PHOTOS_PER_UPLOAD
        return redirect_to @trip, alert: t("containers.photos.too_many", max: Container::MAX_PHOTOS_PER_UPLOAD)
      end

      raise ActiveRecord::RecordInvalid, @trip unless @trip.exit_photos.attach(files)
      @trip.events.create!(user: current_user, event: "exit_photos_uploaded", details: files.size.to_s)
    end
    redirect_to @trip, notice: t("flash.containers.photos_uploaded", count: files.size)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to @trip, alert: t("flash.containers.photos_invalid")
  end

  def destroy
    authorize @trip, :manage_exit_photos?
    @trip.with_lock do
      photo = @trip.exit_photos_attachments.find(params[:photo_id])
      @trip.events.create!(user: current_user, event: "exit_photo_removed", details: photo.id.to_s)
      photo.purge_later
    end
    redirect_to @trip, notice: t("flash.containers.photo_removed")
  end

  def destroy_all
    authorize @trip, :manage_exit_photos?
    @trip.with_lock do
      photos = @trip.exit_photos_attachments.to_a
      photos.each do |photo|
        @trip.events.create!(user: current_user, event: "exit_photo_removed", details: photo.id.to_s)
        photo.purge_later
      end
      @removed_count = photos.size
    end
    redirect_to @trip, notice: t("flash.containers.photos_removed", count: @removed_count)
  end

  def zip
    authorize @trip, :exit_photos?
    return redirect_to @trip, alert: t("flash.containers.photos_none") unless @trip.exit_photos_attachments.exists?

    CargoDispatchTripPhotosZipJob.perform_later(@trip.id, current_user.id,
      { host: request.host, port: request.optional_port, protocol: request.protocol })
    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@trip, "zip_exit_photos"),
      partial: "containers/zip_status",
      locals: { record: @trip, target: helpers.dom_id(@trip, "zip_exit_photos"),
        zip_path: zip_exit_photos_cargo_dispatch_trip_path(@trip), state: :working }
    )
  end

  private

  def valid_photo?(file)
    if file.is_a?(ActiveStorage::Blob)
      return false if file.byte_size > Container::PHOTO_MAX_SIZE || !Container::PHOTO_CONTENT_TYPES.include?(file.content_type)

      file.open { |tempfile| Container::PHOTO_CONTENT_TYPES.include?(Marcel::MimeType.for(tempfile)) }
    elsif file.is_a?(ActionDispatch::Http::UploadedFile)
      file.size <= Container::PHOTO_MAX_SIZE && Container::PHOTO_CONTENT_TYPES.include?(Marcel::MimeType.for(file.tempfile))
    else
      false
    end
  end

  def load_trip
    @trip = policy_scope(CargoDispatchTrip).find(params[:id])
  end
end

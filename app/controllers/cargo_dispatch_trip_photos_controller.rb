class CargoDispatchTripPhotosController < ApplicationController
  before_action :load_trip

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

    unless files.all? { |file| file.is_a?(ActionDispatch::Http::UploadedFile) &&
      file.size <= Container::PHOTO_MAX_SIZE &&
      Container::PHOTO_CONTENT_TYPES.include?(Marcel::MimeType.for(file.tempfile)) }
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

  private

  def load_trip
    @trip = policy_scope(CargoDispatchTrip).find(params[:id])
  end
end

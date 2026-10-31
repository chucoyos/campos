class GateController < ApplicationController
  before_action :authorize_gate

  def index
  end

  def scan
    @token = extract_token(params[:token])
    if @token.blank?
      @error = t("gate.errors.token_required")
      return render :index, status: :unprocessable_entity
    end

    @pass = MovementPass.find_by(token: @token)
    unless @pass
      @error = t("gate.errors.pass_not_found")
      return render :index, status: :not_found
    end

    authorize @pass, :gate?
    @pass.with_lock do
      @pass.vencer! if @pass.may_vencer?
      record_exit_scan if @pass.usable? && @pass.entered_at?
    end
    unless @pass.usable?
      @error = t("gate.errors.pass_unusable")
      return render :index, status: :unprocessable_entity
    end
    if @pass.entered_at? && !@pass.exit_scanned_at?
      @error = t("gate.errors.movement_not_completed")
      return render :index, status: :unprocessable_entity
    end

    redirect_to gate_movement_path(@pass)
  end

  def open_pass
    @pass = MovementPass.find_by(token: params[:token])
    return redirect_to gate_path, alert: t("gate.errors.pass_not_found") unless @pass

    authorize @pass, :gate?
    @pass.with_lock do
      @pass.vencer! if @pass.may_vencer?
      record_exit_scan if @pass.usable? && @pass.entered_at?
    end
    return redirect_to gate_path, alert: t("gate.errors.movement_not_completed") if @pass.entered_at? && !@pass.exit_scanned_at?
    return redirect_to gate_path, alert: t("gate.errors.pass_unusable") unless @pass.usable?

    redirect_to gate_movement_path(@pass)
  end

  def show
    @pass = MovementPass.find(params[:id])
    authorize @pass, :gate?
    @pass.with_lock { @pass.vencer! if @pass.may_vencer? }
    unless @pass.usable?
      redirect_to gate_path, alert: t("gate.errors.pass_unusable")
      return
    end
    if @pass.entered_at? && !@pass.exit_scanned_at?
      redirect_to gate_path, alert: t("gate.errors.scan_exit_qr")
      return
    end

    load_location_options
  end

  def upload_photos
    @pass = MovementPass.find(params[:id])
    authorize @pass, :gate?
    return redirect_to gate_path, alert: t("gate.errors.pass_unusable") unless @pass.usable? && !@pass.entered_at?

    files = Array(params[:photos]).compact_blank
    if files.empty?
      return redirect_to gate_movement_path(@pass), alert: t("gate.errors.photos_missing")
    end
    if @pass.photos.count + files.size > Container::MAX_PHOTOS_PER_UPLOAD
      return redirect_to gate_movement_path(@pass), alert: t("gate.errors.photos_too_many", max: Container::MAX_PHOTOS_PER_UPLOAD)
    end

    @pass.photos.attach(files)
    if @pass.save
      redirect_to gate_movement_path(@pass), notice: t("flash.gate.photos_uploaded", count: files.size)
    else
      load_location_options
      render :show, status: :unprocessable_entity
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to gate_movement_path(@pass), alert: t("gate.errors.photos_invalid")
  end

  def remove_photo
    @pass = MovementPass.find(params[:id])
    authorize @pass, :gate?
    return redirect_to gate_path, alert: t("gate.errors.pass_unusable") unless @pass.usable? && !@pass.entered_at?

    photo = @pass.photos_attachments.find(params[:photo_id])
    photo.purge_later
    redirect_to gate_movement_path(@pass), notice: t("flash.gate.photo_removed")
  rescue ActiveRecord::RecordNotFound
    redirect_to(@pass ? gate_movement_path(@pass) : gate_path, alert: t("gate.errors.photos_invalid"))
  end

  def upload_exit_photos
    @pass = MovementPass.find(params[:id])
    authorize @pass, :gate?
    movement = exit_photos_movement
    return redirect_to gate_path, alert: t("gate.errors.pass_unusable") unless movement

    files = Array(params[:photos]).compact_blank
    return redirect_to gate_movement_path(@pass), alert: t("gate.errors.photos_missing") if files.empty?
    if movement.exit_photos_attachments.count + files.size > Container::MAX_PHOTOS_PER_UPLOAD
      return redirect_to gate_movement_path(@pass), alert: t("gate.errors.photos_too_many", max: Container::MAX_PHOTOS_PER_UPLOAD)
    end

    blobs = files.map { |file| exit_photo_blob(file) }
    invalid = blobs.find { |blob| Container::PHOTO_CONTENT_TYPES.exclude?(blob.content_type) || blob.byte_size > Container::PHOTO_MAX_SIZE }
    if invalid
      blobs.each(&:purge_later)
      return redirect_to gate_movement_path(@pass), alert: t("gate.errors.photos_invalid")
    end

    # El movimiento es inmutable: se crean los adjuntos sin guardar el registro.
    blobs.each { |blob| ActiveStorage::Attachment.create!(name: "exit_photos", record: movement, blob:) }
    redirect_to gate_movement_path(@pass), notice: t("flash.gate.photos_uploaded", count: files.size)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to gate_movement_path(@pass), alert: t("gate.errors.photos_invalid")
  end

  def remove_exit_photo
    @pass = MovementPass.find(params[:id])
    authorize @pass, :gate?
    movement = exit_photos_movement
    return redirect_to gate_path, alert: t("gate.errors.pass_unusable") unless movement

    movement.exit_photos_attachments.find(params[:photo_id]).purge_later
    redirect_to gate_movement_path(@pass), notice: t("flash.gate.photo_removed")
  rescue ActiveRecord::RecordNotFound
    redirect_to gate_movement_path(@pass), alert: t("gate.errors.photos_invalid")
  end

  def complete
    @pass = MovementPass.find(params[:id])
    authorize @pass, :gate?

    second_scan = @pass.entered_at?
    GateMovementService.call(pass: @pass, user: current_user, yard_slot_id: params[:yard_slot_id])
    if second_scan
      redirect_to gate_path, notice: t("flash.gate.exit_completed")
    else
      notice_key = if @pass.ingreso? then "flash.gate.entry_queued"
      elsif @pass.traspaleo? then "flash.gate.transfer_queued"
      else (@pass.movement_plan ? "flash.gate.rehandling_queued" : "flash.gate.loading_queued")
      end
      redirect_to gate_path, notice: t(notice_key)
    end
  rescue GateMovementService::Error => error
    @pass.reload
    return redirect_to gate_path, alert: error.message unless @pass.usable?

    @error = error.message
    load_location_options
    render :show, status: :unprocessable_entity
  end

  private

  # El QR codifica la URL del pase; también se acepta el token solo.
  def extract_token(raw)
    value = raw.to_s.strip
    path = value.match?(%r{\Ahttps?://}i) ? URI.parse(value).path.to_s : value
    path.split("/").reject(&:blank?).last.to_s
  rescue URI::InvalidURIError
    value
  end

  # Las fotos de salida solo se aceptan en el segundo escaneo, cuando el movimiento físico ya existe.
  def exit_photos_movement
    return unless @pass.usable? && @pass.entered_at? && @pass.exit_scanned_at?

    @pass.movement
  end

  def exit_photo_blob(file)
    return ActiveStorage::Blob.find_signed!(file) if file.is_a?(String)

    ActiveStorage::Blob.create_and_upload!(io: file, filename: file.original_filename, content_type: file.content_type)
  end

  def authorize_gate
    authorize MovementPass, :gate?
  end

  def load_location_options
    return unless @pass&.ingreso? && !@pass.entered_at?

    @location_options = GateMovementService.available_slot_records(@pass.container, pass: @pass)
    @suggested_slot = @location_options.first&.fetch(:slot)
  end

  def record_exit_scan
    return false if @pass.exit_scanned_at?
    unless @pass.movement || @pass.movement_plan&.cancelada?
      return false
    end

    @pass.update!(exit_scanned_at: Time.current)
  end
end

class GateController < ApplicationController
  before_action :authorize_gate

  def index
  end

  def scan
    @token = params[:token].to_s.strip
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
    @pass.with_lock { @pass.vencer! if @pass.may_vencer? }
    unless @pass.usable?
      @error = t("gate.errors.pass_unusable")
      return render :index, status: :unprocessable_entity
    end

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

    load_location_options
  end

  def upload_photos
    @pass = MovementPass.find(params[:id])
    authorize @pass, :gate?
    return redirect_to gate_movement_path(@pass), alert: t("gate.errors.pass_unusable") unless @pass.usable?

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
    return redirect_to gate_movement_path(@pass), alert: t("gate.errors.pass_unusable") unless @pass.usable?

    photo = @pass.photos_attachments.find(params[:photo_id])
    photo.purge_later
    redirect_to gate_movement_path(@pass), notice: t("flash.gate.photo_removed")
  rescue ActiveRecord::RecordNotFound
    redirect_to(@pass ? gate_movement_path(@pass) : gate_path, alert: t("gate.errors.photos_invalid"))
  end

  def complete
    @pass = MovementPass.find(params[:id])
    authorize @pass, :gate?

    GateMovementService.call(pass: @pass, user: current_user, yard_slot_id: params[:yard_slot_id])
    redirect_to container_path(@pass.container), notice: t("flash.gate.completed")
  rescue GateMovementService::Error => error
    @pass.reload
    return redirect_to gate_path, alert: error.message unless @pass.usable?

    @error = error.message
    load_location_options
    render :show, status: :unprocessable_entity
  end

  private

  def authorize_gate
    authorize MovementPass, :gate?
  end

  def load_location_options
    return unless @pass&.ingreso?

    @location_options = GateMovementService.available_slot_records(@pass.container, pass: @pass)
    @suggested_slot = @location_options.first&.fetch(:slot)
  end
end

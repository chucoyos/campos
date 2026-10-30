class ContainersController < ApplicationController
  include ActiveStorage::SetCurrent
  include CargoManifestData

  before_action :set_container, only: %i[show edit update destroy photos upload_photos remove_photo remove_photos zip_photos movement_photos]
  before_action :set_photo_section, only: %i[photos upload_photos remove_photos zip_photos]

  def index
    authorize Container
    @pagy, @containers = paginate(apply_filters(policy_scope(Container).includes(:master_bl)).order(:number))
  end

  def show
    @photo_counts = policy(@container).photos? ? ActiveStorage::Attachment.where(record: @container).group(:name).count : {}
    @movements = @container.movements.includes(
      :from_yard_slot, :to_yard_slot, :user, :photos_attachments, movement_pass: :vehicles
    ).order(created_at: :desc)
    load_container_cargo
  end

  def new
    @container = Container.new(params.fetch(:container, {}).permit(:master_bl_id))
    authorize @container
  end

  def create
    @container = Container.new(container_params)
    @container.client_id = current_user.client_id if current_user.client_member? && @container.master_bl_id.blank?
    authorize @container

    if @container.save
      redirect_to (@container.master_bl || containers_path), notice: t("flash.containers.create")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if update_container
      redirect_to containers_path, notice: t("flash.containers.update")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @container.destroy
    redirect_to containers_path, notice: t("flash.containers.destroy")
  end

  def photos
    @photos = @container.public_send(:"#{@section}_photos_attachments").includes(:blob).order(:id)
  end

  def upload_photos
    files = Array(params[:photos]).compact_blank.first(Container::MAX_PHOTOS_PER_UPLOAD)
    return redirect_to photos_return_path, alert: t("flash.containers.photos_missing") if files.empty?

    @container.public_send(:"#{@section}_photos").attach(files)
    if @container.errors.none?
      redirect_to photos_return_path, notice: t("flash.containers.photos_uploaded", count: files.size)
    else
      redirect_to photos_return_path, alert: @container.errors.full_messages.to_sentence
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to photos_return_path, alert: t("flash.containers.photos_invalid")
  end

  def remove_photo
    names = Container::PHOTO_SECTIONS.map { |section| "#{section}_photos" }
    photo = ActiveStorage::Attachment.where(record: @container, name: names).find(params[:photo_id])
    section = photo.name.delete_suffix("_photos")
    photo.purge_later
    redirect_to photos_return_path, notice: t("flash.containers.photo_removed")
  end

  def remove_photos
    count = @container.public_send(:"#{@section}_photos_attachments").count
    @container.public_send(:"#{@section}_photos").purge_later
    redirect_to photos_return_path, notice: t("flash.containers.photos_removed", count: count)
  end

  def zip_photos
    if @container.public_send(:"#{@section}_photos_attachments").none?
      return redirect_to container_path(@container), alert: t("flash.containers.photos_none")
    end

    ContainerPhotosZipJob.perform_later(@container.id, @section, current_user.id,
                                         { host: request.host, port: request.optional_port, protocol: request.protocol })
    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@container, "zip_#{@section}"),
      partial: "containers/zip_status",
      locals: { container: @container, section: @section, state: :working }
    )
  end

  def movement_photos
    @movement = @container.movements.find(params[:id])
    @photos = @movement.photos_attachments.includes(:blob).order(:id)
  end

  private

  # Las fotos también se gestionan desde la desconsolidación; solo se acepta volver a esa ruta interna.
  def photos_return_path
    path = params[:return_to].to_s
    path.match?(%r{\A/deconsolidations/\d+\z}) ? path : container_path(@container)
  end

  def load_container_cargo
    return unless @container.master_bl && policy(CargoManifest).index?

    @cargo_manifest = @container.cargo_manifest
    return load_cargo_manifest_data(@cargo_manifest) if @cargo_manifest && policy(@cargo_manifest).show?

    @cargo_manifest = nil
    @new_cargo_manifest = @container.build_cargo_manifest(client: @container.master_bl.client)
  end


  def set_photo_section
    @section = params[:section].to_s
    head :not_found unless Container::PHOTO_SECTIONS.include?(@section)
  end

  def filter_fields
    [
      { name: "q", type: :text, label: t("filters.number"),
        apply: ->(scope, value) { scope.where("containers.number ILIKE ?", like(value)) } },
      { name: "status", type: :select, label: Container.human_attribute_name(:status),
        options: Container.aasm.states.map { |state| [ t("containers.statuses.#{state.name}"), state.name.to_s ] },
        apply: ->(scope, value) { scope.where(status: value) } },
      { name: "size", type: :select, label: Container.human_attribute_name(:size),
        options: Container::SIZES.map { |size| [ t("containers.sizes.#{size}"), size.to_s ] },
        apply: ->(scope, value) { scope.where(size: value) } },
      { name: "container_type", type: :select, label: Container.human_attribute_name(:container_type),
        options: Container.container_types.keys.map { |type| [ t("containers.types.#{type}"), type ] },
        apply: ->(scope, value) { scope.where(container_type: value) } },
      { name: "master_bl", type: :text, label: t("filters.master_bl"),
        apply: ->(scope, value) { scope.joins(:master_bl).where("master_bls.number ILIKE ?", like(value)) } }
    ]
  end


  def set_container
    @container = policy_scope(Container).find(params[:container_id] || params[:id])
    authorize @container
  end

  def update_container
    Container.transaction do
      raise ActiveRecord::Rollback unless @container.update(container_params.except(:status))
      raise ActiveRecord::Rollback unless correct_status

      true
    end
  end

  def correct_status
    return true unless current_user.admin?

    @container.correct_status(params.dig(:container, :status))
  end

  def container_params
    permitted = %i[number size container_type]
    permitted << :master_bl_id if action_name == "create" || current_user.admin?
    permitted << :status
    permitted << :client_id if action_name == "create" && !current_user.client_member?
    params.expect(container: permitted)
  end
end

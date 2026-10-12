class ContainersController < ApplicationController
  include ActiveStorage::SetCurrent

  before_action :set_container, only: %i[show edit update destroy transition photos upload_photos remove_photo remove_photos zip_photos]
  before_action :set_photo_section, only: %i[photos upload_photos remove_photos zip_photos]

  def index
    authorize Container
    @pagy, @containers = paginate(apply_filters(policy_scope(Container).includes(:master_bl)).order(:number))
  end

  def show
    @photo_counts = policy(@container).photos? ? ActiveStorage::Attachment.where(record: @container).group(:name).count : {}
  end

  def new
    @container = Container.new(params.fetch(:container, {}).permit(:master_bl_id))
    authorize @container
  end

  def create
    @container = Container.new(container_params)
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
    if @container.update(container_params)
      redirect_to containers_path, notice: t("flash.containers.update")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @container.destroy
    redirect_to containers_path, notice: t("flash.containers.destroy")
  end

  def transition
    event = params[:event].to_s

    if TRANSITION_EVENTS.include?(event) && @container.public_send(:"may_#{event}?")
      @container.public_send(:"#{event}!")
      redirect_to @container, notice: t("flash.containers.transition")
    else
      redirect_to @container, alert: t("flash.containers.invalid_transition")
    end
  end

  def photos
    @photos = @container.public_send(:"#{@section}_photos_attachments").includes(:blob).order(:id)
  end

  def upload_photos
    files = Array(params[:photos]).compact_blank.first(Container::MAX_PHOTOS_PER_UPLOAD)
    return redirect_to container_path(@container), alert: t("flash.containers.photos_missing") if files.empty?

    @container.public_send(:"#{@section}_photos").attach(files)
    if @container.errors.none?
      redirect_to container_path(@container), notice: t("flash.containers.photos_uploaded", count: files.size)
    else
      redirect_to container_path(@container), alert: @container.errors.full_messages.to_sentence
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to container_path(@container), alert: t("flash.containers.photos_invalid")
  end

  def remove_photo
    names = Container::PHOTO_SECTIONS.map { |section| "#{section}_photos" }
    photo = ActiveStorage::Attachment.where(record: @container, name: names).find(params[:photo_id])
    section = photo.name.delete_suffix("_photos")
    photo.purge_later
    redirect_to container_path(@container), notice: t("flash.containers.photo_removed")
  end

  def remove_photos
    count = @container.public_send(:"#{@section}_photos_attachments").count
    @container.public_send(:"#{@section}_photos").purge_later
    redirect_to container_path(@container), notice: t("flash.containers.photos_removed", count: count)
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

  private

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

  TRANSITION_EVENTS = %w[llenar vaciar entregar].freeze

  def set_container
    @container = policy_scope(Container).find(params[:id])
    authorize @container
  end

  def container_params
    permitted = %i[number size container_type]
    permitted << :master_bl_id if action_name == "create" || current_user.admin?
    permitted << :status if action_name == "create"
    params.expect(container: permitted)
  end
end

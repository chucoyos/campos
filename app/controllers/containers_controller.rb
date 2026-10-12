class ContainersController < ApplicationController
  before_action :set_container, only: %i[show edit update destroy transition]

  def index
    authorize Container
    @pagy, @containers = paginate(apply_filters(policy_scope(Container).includes(:master_bl)).order(:number))
  end

  def show
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

  private

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
    @container = Container.find(params[:id])
    authorize @container
  end

  def container_params
    permitted = %i[number size container_type master_bl_id]
    permitted << :status if action_name == "create"
    params.expect(container: permitted)
  end
end

class ContainersController < ApplicationController
  before_action :set_container, only: %i[show edit update destroy transition]

  def index
    authorize Container
    @containers = policy_scope(Container).includes(:master_bl).order(:number)
  end

  def show
  end

  def new
    @container = Container.new
    authorize @container
  end

  def create
    @container = Container.new(container_params)
    authorize @container

    if @container.save
      redirect_to containers_path, notice: t("flash.containers.create")
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

class CarriersController < ApplicationController
  before_action :set_carrier, only: %i[show edit update destroy]

  def index
    authorize Carrier
    @carriers = policy_scope(Carrier).order(:name)
  end

  def show
  end

  def new
    @carrier = Carrier.new
    authorize @carrier
  end

  def create
    @carrier = Carrier.new(carrier_params)
    authorize @carrier

    if @carrier.save
      redirect_to carriers_path, notice: t("flash.carriers.create")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @carrier.update(carrier_params)
      redirect_to carriers_path, notice: t("flash.carriers.update")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @carrier.destroy
    redirect_to carriers_path, notice: t("flash.carriers.destroy")
  end

  private

  def set_carrier
    @carrier = Carrier.find(params[:id])
    authorize @carrier
  end

  def carrier_params
    params.expect(carrier: %i[name])
  end
end

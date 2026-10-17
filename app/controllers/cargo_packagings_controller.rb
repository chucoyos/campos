class CargoPackagingsController < ApplicationController
  before_action :set_cargo_packaging, only: %i[edit update destroy]

  def index
    authorize CargoPackaging
    @pagy, @cargo_packagings = paginate(policy_scope(CargoPackaging).order(:name))
  end

  def new
    @cargo_packaging = CargoPackaging.new
    authorize @cargo_packaging
  end

  def create
    @cargo_packaging = CargoPackaging.new(cargo_packaging_params)
    authorize @cargo_packaging
    if @cargo_packaging.save
      redirect_to cargo_packagings_path, notice: t("flash.cargo_packagings.create")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @cargo_packaging.update(cargo_packaging_params)
      redirect_to cargo_packagings_path, notice: t("flash.cargo_packagings.update")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @cargo_packaging.update!(active: false)
    redirect_to cargo_packagings_path, notice: t("flash.cargo_packagings.deactivate")
  end

  private

  def set_cargo_packaging
    @cargo_packaging = CargoPackaging.find(params[:id])
    authorize @cargo_packaging
  end

  def cargo_packaging_params
    params.expect(cargo_packaging: %i[code name tracking_mode weight_required qr_allowed active])
  end
end

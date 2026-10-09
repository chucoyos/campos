class MasterBlsController < ApplicationController
  before_action :set_master_bl, only: %i[show edit update destroy]

  def index
    authorize MasterBl
    @master_bls = policy_scope(MasterBl).includes(:client).order(:number)
  end

  def show
  end

  def new
    @master_bl = MasterBl.new
    authorize @master_bl
  end

  def create
    @master_bl = MasterBl.new(master_bl_params)
    authorize @master_bl

    if @master_bl.save
      redirect_to master_bls_path, notice: t("flash.master_bls.create")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @master_bl.update(master_bl_params)
      redirect_to master_bls_path, notice: t("flash.master_bls.update")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @master_bl.destroy
    redirect_to master_bls_path, notice: t("flash.master_bls.destroy")
  end

  private

  def set_master_bl
    @master_bl = MasterBl.find(params[:id])
    authorize @master_bl
  end

  def master_bl_params
    params.expect(master_bl: %i[number client_id])
  end
end

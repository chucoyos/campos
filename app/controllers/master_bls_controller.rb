class MasterBlsController < ApplicationController
  before_action :set_master_bl, only: %i[show edit update destroy template import]

  def index
    authorize MasterBl
    @master_bls = policy_scope(MasterBl).includes(:client).order(:number)
  end

  def show
    load_containers
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
    if @master_bl.destroy
      redirect_to master_bls_path, notice: t("flash.master_bls.destroy")
    else
      redirect_to @master_bl, alert: t("flash.master_bls.destroy_restricted")
    end
  end

  def template
    send_data ContainerSpreadsheet.template, filename: "#{@master_bl.number.parameterize(preserve_case: true)}.xlsx", type: ContainerSpreadsheet::CONTENT_TYPE, disposition: "attachment"
  end

  def import
    result = ContainerImporter.new(@master_bl, params[:file]).call

    if result.success?
      redirect_to @master_bl, notice: t("flash.master_bls.import", count: result.created)
    else
      @import_errors = result.errors
      load_containers
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_containers
    @containers = @master_bl.containers.order(:number)
  end

  def set_master_bl
    @master_bl = MasterBl.find(params[:id])
    authorize @master_bl
  end

  def master_bl_params
    params.expect(master_bl: %i[number client_id])
  end
end

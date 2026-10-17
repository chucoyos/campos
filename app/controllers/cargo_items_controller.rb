class CargoItemsController < ApplicationController
  include CargoManifestData

  before_action :set_cargo_manifest
  before_action :set_cargo_item, only: %i[show update destroy]

  def show
    authorize @cargo_item
    raise ActiveRecord::RecordNotFound if params[:token].present? && !ActiveSupport::SecurityUtils.secure_compare(params[:token], @cargo_item.qr_token.to_s)
  end

  def create
    @cargo_item = @cargo_manifest.cargo_items.build(cargo_item_params)
    authorize @cargo_item

    if @cargo_item.save
      redirect_back_or_to @cargo_manifest, notice: t("flash.cargo_manifests.item_created")
    else
      load_manifest_items
      render "cargo_manifests/show", status: :unprocessable_entity
    end
  end

  def update
    authorize @cargo_item
    if @cargo_item.update(cargo_item_params)
      redirect_back_or_to @cargo_manifest, notice: t("flash.cargo_manifests.item_updated")
    else
      load_manifest_items
      render "cargo_manifests/show", status: :unprocessable_entity
    end
  end

  def destroy
    authorize @cargo_item
    @cargo_item.destroy!
    redirect_back_or_to @cargo_manifest, notice: t("flash.cargo_manifests.item_destroyed")
  end

  private

  def set_cargo_manifest
    @cargo_manifest = policy_scope(CargoManifest).find(params[:cargo_manifest_id])
  end

  def set_cargo_item
    @cargo_item = @cargo_manifest.cargo_items.find(params[:id])
  end

  def load_manifest_items
    load_cargo_manifest_data(@cargo_manifest, new_item: @cargo_item)
  end

  def cargo_item_params
    params.expect(cargo_item: %i[cargo_packaging_id description quantity weight_kg origin_identifier generate_qr])
  end
end

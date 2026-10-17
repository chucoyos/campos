class WarehouseSlotsController < ApplicationController
  before_action :set_slot

  def show
    authorize @slot
    load_slot_data
  end

  def store
    authorize @slot
    item = movable_items.find(params[:cargo_item_id])
    authorize item, :store?

    item.store_at!(@slot, params[:section], current_user)
    redirect_to warehouse_slot_path(@slot), notice: t("flash.warehouse.stored", code: @slot.code)
  rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => e
    load_slot_data
    flash.now[:alert] = e.respond_to?(:record) ? e.record.errors.full_messages.to_sentence : t("flash.warehouse.invalid_transition")
    render :show, status: :unprocessable_entity
  end

  private

  def set_slot
    @slot = WarehouseSlot.find_by!(qr_token: params[:id])
  end

  def load_slot_data
    @items_by_section = @slot.cargo_items.includes(:cargo_packaging, cargo_manifest: %i[client container]).group_by(&:slot_section)
    @movable_items = movable_items.includes(:cargo_packaging, cargo_manifest: %i[client container]).order(:status, :id).limit(200)
  end

  # Líneas de capturas confirmadas que aún no están en esta ubicación (incluye reubicaciones).
  def movable_items
    CargoItem.joins(:cargo_manifest).where(cargo_manifests: { status: "confirmed" })
             .where("cargo_items.warehouse_slot_id IS DISTINCT FROM ?", @slot.id)
  end
end

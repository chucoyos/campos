class ForkliftController < ApplicationController
  before_action { authorize :forklift, action_name == "index" ? :index? : :"#{action_name}?" }

  def index
    @item = movable_items.find_by(id: params[:item_id]) if params[:item_id].present?
    @slot_codes = WarehouseSlot.enabled.order(:code).pluck(:code) if @item
    @deconsolidations = Deconsolidation.where(status: "desconsolidando").includes(container: :master_bl).order(:id)
    @pending = CargoItem.where(status: "captured").joins(cargo_manifest: { container: :deconsolidation_record })
      .where(deconsolidations: { status: "desconsolidando" }).includes(:cargo_packaging, cargo_manifest: :container).order(:id)
      .group_by { |item| item.cargo_manifest.container }
    @deconsolidations = @deconsolidations.select { |deconsolidation| @pending.key?(deconsolidation.container) }
  end

  # Primer escaneo: el bulto (QR del rollo/palet) o una línea elegida a mano cuando no tiene QR.
  def pick
    item = if params[:item_id].present?
      movable_items.find_by(id: params[:item_id])
    else
      movable_items.find_by(qr_token: scanned_item_token)
    end
    return redirect_to forklift_path, alert: t("flash.forklift.item_not_found") unless item

    redirect_to forklift_path(item_id: item.id)
  end

  # Segundo escaneo: el QR fijo de la ubicación confirma el movimiento.
  def store
    item = movable_items.find_by(id: params[:item_id])
    return redirect_to forklift_path, alert: t("flash.forklift.item_not_found") unless item

    token = scanned_slot_token
    slot = WarehouseSlot.find_by(qr_token: token) || WarehouseSlot.find_by(code: token.upcase)
    return redirect_to forklift_path(item_id: item.id), alert: t("flash.forklift.slot_not_found") unless slot&.enabled?
    return redirect_to forklift_path(item_id: item.id), alert: t("flash.forklift.not_deconsolidating") if awaiting_opening?(item)

    item.store_at!(slot, params[:section], current_user)
    redirect_to forklift_path, notice: t("flash.forklift.stored", item: item.description, location: item.location_label)
  rescue AASM::InvalidTransition, ActiveRecord::RecordInvalid => error
    message = error.respond_to?(:record) ? error.record.errors.full_messages.to_sentence : t("flash.warehouse.invalid_transition")
    redirect_to forklift_path(item_id: item&.id), alert: message
  end

  private

  def movable_items
    CargoItem.joins(:cargo_manifest).where(cargo_manifests: { status: "confirmed" })
  end

  def awaiting_opening?(item)
    item.cargo_manifest.container&.deconsolidation_record&.apertura?
  end

  # El QR de un bulto es una URL con ?token=; el de una ubicación termina en su token.
  def scanned_item_token
    raw = params[:code].to_s.strip
    return raw unless raw.match?(%r{\Ahttps?://}i)

    Rack::Utils.parse_query(URI.parse(raw).query.to_s)["token"].to_s
  rescue URI::InvalidURIError
    ""
  end

  def scanned_slot_token
    raw = params[:code].to_s.strip
    path = raw.match?(%r{\Ahttps?://}i) ? URI.parse(raw).path.to_s : raw
    path.split("/").reject(&:blank?).last.to_s
  rescue URI::InvalidURIError
    ""
  end
end

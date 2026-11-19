class WarehouseController < ApplicationController
  def index
    authorize WarehouseSlot
    @bays = WarehouseBay.ordered.includes(:warehouse_slots)
    stored_items = CargoItem.physically_stored
    @section_counts = stored_items.unscope(:select).group(:warehouse_slot_id, :slot_section).count
    @item_counts = @section_counts.each_with_object(Hash.new(0)) { |((slot_id, _), count), totals| totals[slot_id] += count }
    @slot_clients = stored_items.joins(cargo_manifest: :client).distinct
      .pluck(:warehouse_slot_id, "clients.name", "clients.container_color")
      .group_by(&:first).transform_values { |rows| rows.map { |_, name, color| { name:, color: } } }
  end

  def labels
    authorize WarehouseSlot
    @slots = WarehouseSlot.ordered.includes(:warehouse_bay)
  end
end

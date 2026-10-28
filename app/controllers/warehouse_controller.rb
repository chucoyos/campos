class WarehouseController < ApplicationController
  def index
    authorize WarehouseSlot
    @bays = WarehouseBay.ordered.includes(:warehouse_slots)
    @section_counts = CargoItem.where.not(warehouse_slot_id: nil).group(:warehouse_slot_id, :slot_section).count
    @item_counts = @section_counts.each_with_object(Hash.new(0)) { |((slot_id, _), count), totals| totals[slot_id] += count }
    @slot_clients = CargoItem.where.not(warehouse_slot_id: nil).joins(cargo_manifest: :client).distinct
      .pluck(:warehouse_slot_id, "clients.name", "clients.container_color")
      .group_by(&:first).transform_values { |rows| rows.map { |_, name, color| { name:, color: } } }
  end

  def labels
    authorize WarehouseSlot
    @slots = WarehouseSlot.ordered.includes(:warehouse_bay)
  end
end

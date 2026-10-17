class WarehouseController < ApplicationController
  def index
    authorize WarehouseSlot
    @bays = WarehouseBay.ordered.includes(:warehouse_slots)
    @section_counts = CargoItem.where.not(warehouse_slot_id: nil).group(:warehouse_slot_id, :slot_section).count
    @item_counts = @section_counts.each_with_object(Hash.new(0)) { |((slot_id, _), count), totals| totals[slot_id] += count }
  end

  def labels
    authorize WarehouseSlot
    @slots = WarehouseSlot.ordered.includes(:warehouse_bay)
  end
end

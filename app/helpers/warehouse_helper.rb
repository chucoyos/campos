module WarehouseHelper
  def warehouse_map_data(bays, section_counts, slot_clients = {})
    bays.map do |bay|
      {
        label: t("warehouse.index.bay", number: bay.number),
        free_space_after: WarehouseCatalog::FREE_SPACE_AFTER[bay.number],
        slots: bay.warehouse_slots.sort_by(&:number).map do |slot|
          sections = WarehouseSlot::SECTIONS.index_with { |section| section_counts.fetch([ slot.id, section ], 0) }
          clients = slot_clients.fetch(slot.id, [])
          color = clients.first[:color] if clients.size == 1
          { code: slot.code, number: slot.number, enabled: slot.enabled, url: warehouse_slot_path(slot), sections: sections,
            items: sections.values.sum, color: color, clients: clients.map { |client| client[:name] }.sort }
        end
      }
    end
  end

  def warehouse_slot_qr_svg(slot)
    url = warehouse_slot_url(slot, host: request.host, protocol: request.protocol)
    RQRCode::QRCode.new(url).as_svg(module_size: 4, standalone: true, viewbox: true)
  end
end

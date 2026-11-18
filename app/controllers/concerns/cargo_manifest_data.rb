module CargoManifestData
  extend ActiveSupport::Concern

  private

  def load_cargo_manifest_data(manifest, new_item: manifest.cargo_items.build)
    @cargo_items = manifest.cargo_items.includes(:cargo_packaging, :warehouse_slot).order(:id)
    item_ids = @cargo_items.map(&:id)
    @delivered_quantities = CargoDispatchAllocation.delivered.where(cargo_item_id: item_ids).group(:cargo_item_id).sum(:loaded_quantity)
    @delivery_history = CargoDispatchAllocation.with_delivery_details.where(cargo_item_id: item_ids).group_by(&:cargo_item_id)
    @new_cargo_item = new_item
    @active_packagings = CargoPackaging.active.order(:name)
  end
end

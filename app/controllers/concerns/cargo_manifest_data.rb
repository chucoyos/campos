module CargoManifestData
  extend ActiveSupport::Concern

  private

  def load_cargo_manifest_data(manifest, new_item: manifest.cargo_items.build)
    @cargo_items = manifest.cargo_items.includes(:cargo_packaging).order(:id)
    @new_cargo_item = new_item
    @active_packagings = CargoPackaging.active.order(:name)
  end
end

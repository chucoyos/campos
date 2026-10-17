module CargoItemsHelper
  PACKAGING_ICONS = { "pallet" => "view_in_ar", "roll" => "album", "box" => "package_2" }.freeze

  def packaging_icon(cargo_packaging)
    material_icon(PACKAGING_ICONS.fetch(cargo_packaging.code, "inventory_2"))
  end

  def manifest_icon(cargo_manifest)
    material_icon(cargo_manifest.container ? "inventory_2" : "local_shipping")
  end

  def cargo_qr_svg(cargo_item)
    url = cargo_manifest_cargo_item_url(
      cargo_item.cargo_manifest,
      cargo_item,
      token: cargo_item.qr_token,
      host: request.host,
      protocol: request.protocol
    )
    RQRCode::QRCode.new(url).as_svg(module_size: 4, standalone: true).html_safe
  end
end

module CargoItemsHelper
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

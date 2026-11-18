require "prawn"
require "rqrcode"

Prawn::Fonts::AFM.hide_m17n_warning = true

class CargoDispatchPassPdf
  QR_SIZE = 220
  QR_BOTTOM_SPACE = 25

  def initialize(pass, gate_url:)
    @pass = pass
    @gate_url = gate_url
  end

  def render
    pdf = Prawn::Document.new(page_size: "LETTER", margin: 48)
    trip = @pass.cargo_dispatch_trip
    pdf.image Rails.root.join("app/assets/images/logo_full.png").to_s, width: 170, position: :left
    pdf.move_down 14
    pdf.text safe(I18n.t("cargo_dispatch.ui.gate_title")), size: 22, style: :bold
    pdf.move_down 16
    [
      I18n.t("cargo_dispatch.ui.trip_number", number: trip.id),
      trip.carrier&.name || trip.transport_name,
      @pass.operator_name,
      @pass.plate,
      @pass.economic_number,
      I18n.t("movement_passes.unit_types.#{@pass.unit_type}"),
      I18n.l(@pass.expires_at.in_time_zone, format: :long)
    ].compact_blank.each { |line| pdf.text safe(line), size: 12 }
    pdf.move_down 20
    pdf.start_new_page if pdf.cursor < QR_SIZE + QR_BOTTOM_SPACE
    modules = RQRCode::QRCode.new(@gate_url, level: :m).modules
    cell = QR_SIZE.to_f / (modules.size + 8)
    left = (pdf.bounds.width - QR_SIZE) / 2
    top = pdf.cursor
    modules.each_with_index do |row, y|
      row.each_with_index do |dark, x|
        pdf.fill_rectangle [ left + ((x + 4) * cell), top - ((y + 4) * cell) ], cell, cell if dark
      end
    end
    pdf.move_cursor_to top - QR_SIZE - 8
    pdf.text safe(@pass.token), align: :center, size: 9
    pdf.render
  end

  private

  def safe(value) = value.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8")
end

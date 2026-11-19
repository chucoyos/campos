require "prawn"
require "rqrcode"

Prawn::Fonts::AFM.hide_m17n_warning = true

class CargoDispatchPassPdf
  include PdfDocumentStyle

  QR_SIZE = 220
  QR_BOTTOM_SPACE = 25

  def initialize(pass, gate_url:)
    @pass = pass
    @gate_url = gate_url
  end

  def render
    pdf = Prawn::Document.new(page_size: "LETTER", margin: 40)
    trip = @pass.cargo_dispatch_trip
    draw_pdf_header(pdf, title: I18n.t("cargo_dispatch.ui.gate_title"),
      subtitle: I18n.t("cargo_dispatch.ui.trip_number", number: trip.id))
    rows = [
      [ t(:transport), trip.carrier&.name || trip.transport_name ],
      [ t(:operator), @pass.operator_name ],
      [ t(:plate), @pass.plate ],
      [ t(:economic_number), @pass.economic_number.presence || t(:unavailable) ],
      [ t(:unit), I18n.t("movement_passes.unit_types.#{@pass.unit_type}") ],
      [ t(:expires_at), I18n.l(@pass.expires_at.in_time_zone, format: :long) ]
    ]
    draw_pdf_section(pdf, t(:details))
    draw_pdf_table(pdf, rows, widths: [ 0.32, 0.68 ], font_size: 10)
    pdf.move_down 20
    pdf.start_new_page if pdf.cursor < QR_SIZE + QR_BOTTOM_SPACE
    modules = RQRCode::QRCode.new(@gate_url, level: :m).modules
    cell = QR_SIZE.to_f / (modules.size + 8)
    left = (pdf.bounds.width - QR_SIZE) / 2
    top = pdf.cursor
    pdf.fill_color "FFFFFF"
    pdf.fill_rectangle [ left, top ], QR_SIZE, QR_SIZE
    pdf.stroke_color GRID
    pdf.stroke_rectangle [ left, top ], QR_SIZE, QR_SIZE
    pdf.fill_color "000000"
    modules.each_with_index do |row, y|
      row.each_with_index do |dark, x|
        pdf.fill_rectangle [ left + ((x + 4) * cell), top - ((y + 4) * cell) ], cell, cell if dark
      end
    end
    pdf.move_cursor_to top - QR_SIZE - 8
    pdf.text pdf_safe(@pass.token), align: :center, size: 9
    pdf.render
  end

  private

  def t(key) = I18n.t("cargo_dispatch.pdf.#{key}")
end

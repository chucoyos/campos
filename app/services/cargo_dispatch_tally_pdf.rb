require "prawn"

class CargoDispatchTallyPdf
  include PdfDocumentStyle

  def initialize(trip)
    @trip = trip
  end

  def render
    pass = @trip.passes.where.not(entered_at: nil).order(:id).sole
    confirmation = @trip.events.find_by!(event: "loading_confirmed")
    allocations = @trip.allocations.where(status: "confirmed").includes(cargo_item: :cargo_packaging).order(:id).to_a
    if @trip.origin_type == "mbl"
      ActiveRecord::Associations::Preloader.new(records: allocations.map(&:cargo_item),
        associations: { cargo_manifest: { container: :master_bl } }).call
    end

    pdf = Prawn::Document.new(page_size: "LETTER", margin: [ 36, 36, 42, 36 ],
      info: { Title: "#{t('title')} #{t('trip', number: @trip.id)}" })
    draw_pdf_header(pdf, title: t("title"), subtitle: t("trip", number: @trip.id))
    details = [
      [ t("client_label"), @trip.cargo_dispatch_request.client.name ],
      [ t("destination_label"), @trip.cargo_dispatch_request.destination ],
      [ t("transport_label"), @trip.carrier&.name || @trip.transport_name ],
      [ t("operator_label"), pass.operator_name ],
      [ t("vehicle_label"), t("vehicle", plate: pass.plate, unit: I18n.t("movement_passes.unit_types.#{pass.unit_type}"),
        economic: pass.economic_number.presence || t("unavailable")) ],
      [ t("confirmed_at_label"), I18n.l(confirmation.created_at.in_time_zone, format: :long) ],
      [
        pass.completed_at? ? t("exited_at_label") : t("exit_label"),
        pass.completed_at? ? I18n.l(pass.completed_at.in_time_zone, format: :long) : t("exit_pending")
      ]
    ]
    draw_pdf_section(pdf, t("trip_details"))
    draw_pdf_table(pdf, details, widths: [ 0.28, 0.72 ], font_size: 9)
    draw_pdf_section(pdf, t("items"))
    headers = [ t("description"), t("part"), t("mbl"), t("container"), t("quantity"), t("weight") ]
    rows = allocations.map do |allocation|
      item = allocation.cargo_item
      container = item.cargo_manifest.container if @trip.origin_type == "mbl"
      weight = item.weight_kg ? "#{I18n.with_locale(:es) { ActionController::Base.helpers.number_with_precision(item.weight_kg * allocation.loaded_quantity, precision: 3) }} kg" : t("unavailable")
      [
        "#{item.description}\n#{item.cargo_packaging.name}",
        item.origin_identifier.presence || t("unavailable"),
        container&.master_bl&.number || t("unavailable"),
        container&.number || t("unavailable"),
        allocation.loaded_quantity.to_s,
        weight
      ]
    end
    if allocations.empty?
      rows << [ t("no_cargo", reason: confirmation.details.presence || t("unavailable")), "", "", "", "", "" ]
    end
    draw_pdf_table(pdf, rows, widths: [ 0.30, 0.14, 0.15, 0.15, 0.10, 0.16 ], headers: headers, font_size: 8)
    pdf.move_down 12
    pdf.fill_color SURFACE
    pdf.fill_rounded_rectangle [ 0, pdf.cursor ], pdf.bounds.width, 44, 6
    pdf.fill_color NAVY
    pdf.text safe(t("total", count: allocations.sum(&:loaded_quantity))), size: 11, style: :bold, indent_paragraphs: 10
    weighted_allocations = allocations.select { |allocation| allocation.cargo_item.weight_kg.present? }
    known_weight = weighted_allocations.sum { |allocation| allocation.cargo_item.weight_kg * allocation.loaded_quantity }
    unknown_quantity = allocations.sum { |allocation| allocation.cargo_item.weight_kg ? 0 : allocation.loaded_quantity }
    weight_label = weighted_allocations.empty? ? t("unavailable") : "#{ActionController::Base.helpers.number_with_precision(known_weight, precision: 3)} kg"
    pdf.fill_color TEXT
    pdf.move_down 4
    pdf.text safe(t("known_weight", weight: weight_label, count: unknown_quantity)), size: 9, indent_paragraphs: 10
    pdf.move_down 8
    pdf.move_down 24
    pdf.text safe(t("signatures")), size: 9, align: :center
    disclaimer(pdf)
    pdf.render
  end

  private

  def t(key, **options) = I18n.t("cargo_dispatch.tally.#{key}", **options)

  def safe(value) = pdf_safe(value)

  def disclaimer(pdf)
    text = t("footer_disclaimer")
    height = pdf.height_of(safe(text), width: pdf.bounds.width - 24, size: 7.5, leading: 2) + 20
    pdf.start_new_page if pdf.cursor < height + 12
    pdf.move_down 12
    top = pdf.cursor
    pdf.fill_color SURFACE
    pdf.fill_rounded_rectangle [ 0, top ], pdf.bounds.width, height, 6
    pdf.fill_color MUTED
    pdf.text_box safe(text), at: [ 12, top - 10 ], width: pdf.bounds.width - 24, height: height - 20,
      size: 7.5, leading: 2, align: :justify
    pdf.move_cursor_to top - height
    pdf.fill_color TEXT
  end
end

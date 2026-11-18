require "prawn"

class CargoDispatchTallyPdf
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

    pdf = Prawn::Document.new(page_size: "LETTER", margin: 40)
    pdf.image Rails.root.join("app/assets/images/logo_full.png").to_s, width: 170, position: :left
    pdf.move_down 14
    pdf.text safe(t("title")), size: 18, style: :bold
    pdf.text safe(t("trip", number: @trip.id)), size: 12
    pdf.move_down 12
    [
      t("client", value: @trip.cargo_dispatch_request.client.name),
      t("destination", value: @trip.cargo_dispatch_request.destination),
      t("transport", value: @trip.carrier&.name || @trip.transport_name),
      t("operator", value: pass.operator_name),
      t("vehicle", plate: pass.plate, unit: I18n.t("movement_passes.unit_types.#{pass.unit_type}"), economic: pass.economic_number.presence || t("unavailable")),
      t("confirmed_at", time: I18n.l(confirmation.created_at.in_time_zone, format: :long)),
      pass.completed_at? ? t("exited_at", time: I18n.l(pass.completed_at.in_time_zone, format: :long)) : t("exit_pending")
    ].each { |line| pdf.text safe(line), size: 10 }
    pdf.move_down 12
    pdf.text safe(t("items")), size: 12, style: :bold
    if allocations.empty?
      pdf.text safe(t("no_cargo", reason: confirmation.details.presence || t("unavailable"))), size: 10
    end
    allocations.each_with_index do |allocation, index|
      item = allocation.cargo_item
      container = item.cargo_manifest.container if @trip.origin_type == "mbl"
      weight = item.weight_kg ? "#{I18n.with_locale(:es) { ActionController::Base.helpers.number_with_precision(item.weight_kg * allocation.loaded_quantity, precision: 3) }} kg" : t("unavailable")
      pdf.move_down 6
      pdf.text safe(t("item", number: index + 1, description: item.description, packaging: item.cargo_packaging.name,
        quantity: allocation.loaded_quantity, part: item.origin_identifier.presence || t("unavailable"),
        container: container&.number || t("unavailable"), mbl: container&.master_bl&.number || t("unavailable"), weight: weight)), size: 10
    end
    pdf.move_down 12
    pdf.text safe(t("total", count: allocations.sum(&:loaded_quantity))), size: 11, style: :bold
    weighted_allocations = allocations.select { |allocation| allocation.cargo_item.weight_kg.present? }
    known_weight = weighted_allocations.sum { |allocation| allocation.cargo_item.weight_kg * allocation.loaded_quantity }
    unknown_quantity = allocations.sum { |allocation| allocation.cargo_item.weight_kg ? 0 : allocation.loaded_quantity }
    weight_label = weighted_allocations.empty? ? t("unavailable") : "#{ActionController::Base.helpers.number_with_precision(known_weight, precision: 3)} kg"
    pdf.text safe(t("known_weight", weight: weight_label, count: unknown_quantity)), size: 10
    pdf.move_down 24
    pdf.text safe(t("signatures")), size: 10
    pdf.render
  end

  private

  def t(key, **options) = I18n.t("cargo_dispatch.tally.#{key}", **options)
  def safe(value) = value.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8")
end

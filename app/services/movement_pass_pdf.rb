require "prawn"
require "rqrcode"

Prawn::Fonts::AFM.hide_m17n_warning = true

# PDF imprimible del pase: datos del movimiento, vehículos y un QR que contiene solo el token opaco.
class MovementPassPdf
  QR_SIZE = 220

  def initialize(pass)
    @pass = pass
  end

  def render
    pdf = Prawn::Document.new(page_size: "LETTER", margin: 48, info: { Title: "#{t(:title)} #{@pass.container.number}" })
    header(pdf)
    summary(pdf)
    vehicles(pdf)
    qr_code(pdf)
    footer(pdf)
    pdf.render
  end

  private

  def t(key, **options) = I18n.t("movement_passes.pdf.#{key}", **options)

  # Las fuentes integradas de Prawn solo admiten Windows-1252.
  def safe(value) = value.to_s.encode("Windows-1252", invalid: :replace, undef: :replace, replace: "?").encode("UTF-8")

  def time(value) = I18n.l(value.in_time_zone, format: :long)

  def header(pdf)
    pdf.fill_color "0B3C5D"
    pdf.text safe(t(:title)), size: 24, style: :bold
    pdf.fill_color "000000"
    pdf.text safe(I18n.t("movement_passes.types.#{@pass.movement_type}").upcase), size: 40, style: :bold
    pdf.move_down 12
  end

  def summary(pdf)
    container = @pass.container
    rows = [
      [ Container.human_attribute_name(:number), container.number ],
      [ Container.human_attribute_name(:size), "#{container.size}'" ]
    ]
    rows << [ MasterBl.model_name.human, container.master_bl.number ] if container.master_bl
    rows << [ Client.model_name.human, @pass.client&.name ] if @pass.client && !@pass.with_master_bl?
    rows << [ MovementPass.human_attribute_name(:load_status), I18n.t("movement_passes.load_statuses.#{@pass.load_status}") ] if @pass.load_status
    rows << [ t(:issued_at), time(@pass.issued_at) ]
    rows << [ t(:expires_at), time(@pass.expires_at) ]
    definition_list(pdf, rows)
  end

  def vehicles(pdf)
    @pass.vehicles.sort_by(&:role).each do |vehicle|
      pdf.move_down 10
      pdf.text safe(t("vehicle_#{vehicle.role}")), size: 14, style: :bold
      definition_list(pdf, [
        [ MovementPassVehicle.human_attribute_name(:company_name), vehicle.company_name ],
        [ MovementPassVehicle.human_attribute_name(:operator_name), vehicle.operator_name ],
        [ MovementPassVehicle.human_attribute_name(:plate), vehicle.plate ],
        [ MovementPassVehicle.human_attribute_name(:unit_type), I18n.t("movement_passes.unit_types.#{vehicle.unit_type}") ]
      ])
    end
  end

  def definition_list(pdf, rows)
    rows.each do |label, value|
      pdf.formatted_text [ { text: "#{safe(label)}: ", styles: [ :bold ], size: 12 }, { text: safe(value), size: 12 } ]
    end
  end

  def qr_code(pdf)
    modules = RQRCode::QRCode.new(@pass.token, level: :m).modules
    quiet = 4
    cell = QR_SIZE.to_f / (modules.size + (quiet * 2))
    pdf.move_down 16
    left = (pdf.bounds.width - QR_SIZE) / 2
    top = pdf.cursor

    pdf.fill_color "FFFFFF"
    pdf.fill_rectangle [ left, top ], QR_SIZE, QR_SIZE
    pdf.fill_color "000000"
    modules.each_with_index do |row, y|
      row.each_with_index do |dark, x|
        pdf.fill_rectangle [ left + ((x + quiet) * cell), top - ((y + quiet) * cell) ], cell, cell if dark
      end
    end
    pdf.move_cursor_to top - QR_SIZE - 8
    pdf.text @pass.token, size: 9, align: :center, font: "Courier"
  end

  def footer(pdf)
    pdf.move_down 10
    pdf.text safe(t(:single_use, hours: MovementPass::VALIDITY.in_hours.to_i)), size: 10, align: :center, color: "555555"
  end
end

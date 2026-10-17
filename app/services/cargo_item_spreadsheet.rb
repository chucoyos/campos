# Genera la plantilla de Excel para capturar mercancías de un registro.
class CargoItemSpreadsheet
  CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet".freeze
  COLUMN_COUNT = 6

  def self.template
    new.template
  end

  def template
    package = Axlsx::Package.new
    workbook = package.workbook
    styles = build_styles(workbook)
    packagings = CargoPackaging.active.order(:name).to_a
    last_row = CargoItemImporter::MAX_ROWS + 1

    workbook.add_worksheet(name: I18n.t("cargo_import.sheet")) do |sheet|
      sheet.add_row headers, style: styles[:header], height: 30
      sheet.column_widths 22, 38, 12, 14, 26, 14
      sheet.sheet_view.pane { |pane| pane.top_left_cell = "A2"; pane.state = :frozen; pane.y_split = 1 }

      sheet.add_data_validation("A2:A#{last_row}", type: :list, formula1: "'#{catalog_sheet_name}'!$A$2:$A$#{packagings.size + 1}",
        allowBlank: false, showErrorMessage: true, errorTitle: headers[0], error: I18n.t("cargo_import.validation.packaging"))
      sheet.add_data_validation("C2:C#{last_row}", type: :whole, operator: :greaterThanOrEqual, formula1: "1",
        showErrorMessage: true, errorTitle: headers[2], error: I18n.t("cargo_import.validation.quantity"))
      sheet.add_data_validation("D2:D#{last_row}", type: :decimal, operator: :greaterThan, formula1: "0",
        allowBlank: true, showErrorMessage: true, errorTitle: headers[3], error: I18n.t("cargo_import.validation.weight"))
      sheet.add_data_validation("F2:F#{last_row}", type: :list, formula1: "\"#{yes_no.join(',')}\"",
        allowBlank: true, showErrorMessage: true, errorTitle: headers[5], error: I18n.t("cargo_import.validation.yes_no"))
    end

    workbook.add_worksheet(name: catalog_sheet_name) do |sheet|
      sheet.add_row catalog_headers, style: styles[:header], height: 30
      packagings.each do |packaging|
        sheet.add_row [ packaging.name, packaging.code, I18n.t("cargo_packagings.tracking_modes.#{packaging.tracking_mode}"),
                        yes_no_label(packaging.weight_required?), yes_no_label(packaging.qr_allowed?) ], style: styles[:cell]
      end
      sheet.column_widths 22, 14, 26, 18, 16
    end

    workbook.add_worksheet(name: I18n.t("container_import.instructions_sheet")) do |sheet|
      sheet.add_row [ I18n.t("cargo_import.instructions_title") ], style: styles[:title], height: 30
      I18n.t("cargo_import.instructions").each { |line| sheet.add_row [ line ], style: styles[:wrap] }
      sheet.column_widths 110
    end

    package.to_stream.read
  end

  private

  def headers
    [ CargoItem.human_attribute_name(:cargo_packaging), CargoItem.human_attribute_name(:description),
      CargoItem.human_attribute_name(:quantity), CargoItem.human_attribute_name(:weight_kg),
      CargoItem.human_attribute_name(:origin_identifier), CargoItem.human_attribute_name(:generate_qr) ]
  end

  def catalog_headers
    I18n.t("cargo_import.catalog_headers")
  end

  def catalog_sheet_name = I18n.t("cargo_import.catalog_sheet")

  def yes_no = [ I18n.t("cargo_import.yes"), I18n.t("cargo_import.no") ]

  def yes_no_label(value) = value ? yes_no.first : yes_no.last

  def build_styles(workbook)
    border = { style: :thin, color: "CBD5E1" }
    styles = workbook.styles
    {
      header: styles.add_style(b: true, fg_color: "FFFFFF", bg_color: "1E3A8A", sz: 11, border: border,
                               alignment: { horizontal: :center, vertical: :center, wrap_text: true }),
      cell: styles.add_style(border: border, alignment: { vertical: :center }),
      title: styles.add_style(b: true, sz: 14, fg_color: "1E3A8A", alignment: { vertical: :center }),
      wrap: styles.add_style(alignment: { wrap_text: true, vertical: :top })
    }
  end
end

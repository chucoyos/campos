# Genera la plantilla de Excel para cargar contenedores de un MBL.
class ContainerSpreadsheet
  CONTENT_TYPE = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet".freeze

  def self.template
    new.template
  end

  def template
    package = Axlsx::Package.new
    workbook = package.workbook
    header = workbook.styles.add_style(b: true, bg_color: "E0E7FF", border: { style: :thin, color: "CBD5E1" })

    workbook.add_worksheet(name: I18n.t("container_import.sheet")) do |sheet|
      sheet.add_row [ Container.human_attribute_name(:number), Container.human_attribute_name(:size), Container.human_attribute_name(:container_type) ], style: header
      sheet.column_widths 20, 12, 16
      sheet.add_data_validation("B2:B#{ContainerImporter::MAX_ROWS + 1}", type: :list, formula1: "\"#{Container::SIZES.join(',')}\"", showErrorMessage: true)
      sheet.add_data_validation("C2:C#{ContainerImporter::MAX_ROWS + 1}", type: :list, formula1: "\"#{type_labels.join(',')}\"", showErrorMessage: true)
    end

    workbook.add_worksheet(name: I18n.t("container_import.instructions_sheet")) do |sheet|
      I18n.t("container_import.instructions").each { |line| sheet.add_row [ line ] }
      sheet.column_widths 100
    end

    package.to_stream.read
  end

  private

  def type_labels
    Container.container_types.keys.map { |type| I18n.t("containers.types.#{type}") }
  end
end

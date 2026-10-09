require "tempfile"

module XlsxHelper
  # Construye un .xlsx temporal con las filas dadas (sin encabezado).
  def build_xlsx(rows, header: %w[Número Tamaño Tipo], filename: "contenedores.xlsx")
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Contenedores") do |sheet|
      sheet.add_row header
      rows.each { |row| sheet.add_row row }
    end
    file = Tempfile.new([ "contenedores", ".xlsx" ])
    file.binmode
    file.write(package.to_stream.read)
    file.flush
    Rack::Test::UploadedFile.new(file.path, ContainerSpreadsheet::CONTENT_TYPE, true, original_filename: filename)
  end
end

RSpec.configure { |config| config.include XlsxHelper }

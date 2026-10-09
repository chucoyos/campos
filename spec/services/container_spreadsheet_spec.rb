require "rails_helper"

RSpec.describe ContainerSpreadsheet do
  it "generates a template that can be read back" do
    file = Tempfile.new([ "plantilla", ".xlsx" ]).tap { |f| f.binmode; f.write(described_class.template); f.flush }
    book = Roo::Excelx.new(file.path)

    expect(book.sheets).to eq([ "Contenedores", "Instrucciones" ])
    expect(book.sheet("Contenedores").row(1)).to eq([ "Número", "Tamaño", "Tipo" ])
  end
end

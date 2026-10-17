require "rails_helper"

RSpec.describe CargoItemSpreadsheet do
  let!(:roll) { create(:cargo_packaging, name: "Rollo") }
  let!(:box) { create(:cargo_packaging, :box) }

  before { create(:cargo_packaging, name: "Inactivo", active: false) }

  it "generates a template with the active catalog that can be read back" do
    file = Tempfile.new([ "plantilla", ".xlsx" ]).tap { |f| f.binmode; f.write(described_class.template); f.flush }
    book = Roo::Excelx.new(file.path)

    expect(book.sheets).to eq([ "Mercancías", "Catálogo de embalajes", "Instrucciones" ])
    expect(book.sheet("Mercancías").row(1)).to eq([ "Embalaje", "Descripción de la mercancía", "Cantidad", "Peso (kg)", "Identificador de origen", "Generar etiqueta QR" ])
    expect(book.sheet("Catálogo de embalajes").column(1).drop(1)).to contain_exactly("Caja", "Rollo")
  end

  it "leaves the description column blank and unrestricted" do
    file = Tempfile.new([ "plantilla", ".xlsx" ]).tap { |f| f.binmode; f.write(described_class.template); f.flush }
    sheet = Roo::Excelx.new(file.path).sheet("Mercancías")
    xml = Zip::File.open(file.path) { |zip| zip.read("xl/worksheets/sheet1.xml") }

    expect(sheet.last_row).to eq(1)
    expect(xml).not_to include('sqref="B2:B2001"')
  end

  it "can be imported by packaging name" do
    manifest = create(:cargo_manifest)
    file = build_xlsx([ [ "rollo", "Rollo acero", 1, 800, nil, "Sí" ] ], header: %w[A B C D E F], filename: "m.xlsx")

    expect(CargoItemImporter.new(manifest, file).call).to be_success
    expect(manifest.cargo_items.first.cargo_packaging).to eq(roll)
  end
end

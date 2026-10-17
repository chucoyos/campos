require "rails_helper"

RSpec.describe CargoItemImporter do
  let(:manifest) { create(:cargo_manifest) }
  let!(:roll) { create(:cargo_packaging) }
  let!(:box) { create(:cargo_packaging, :box) }

  def import_rows(rows)
    headers = %w[Embalaje Descripción Cantidad Peso_kg Identificador_origen Generar_QR]
    file = build_xlsx(rows, header: headers, filename: "mercancias.xlsx")
    described_class.new(manifest, file).call
  end

  it "imports mixed individual and aggregate packaging lines" do
    result = import_rows([
      [ roll.code, "Rollo acero", 1, 840, nil, "No" ],
      [ box.code, "Repuestos", 10, nil, nil, "No" ]
    ])

    expect(result).to be_success
    expect(result.created).to eq(2)
    expect(manifest.cargo_items.pluck(:quantity)).to contain_exactly(1, 10)
  end

  it "does not import partial data if one row is invalid" do
    result = import_rows([
      [ roll.code, "Rollo acero", 1, 840, nil, "No" ],
      [ box.code, "Repuestos", 10, 100, nil, "No" ]
    ])

    expect(result).not_to be_success
    expect(result.created).to eq(0)
    expect(manifest.cargo_items.reload).to be_empty
  end

  it "rejects nonnumeric optional weights instead of silently dropping them" do
    result = import_rows([
      [ box.code, "Repuestos", 10, "peso inválido", nil, "No" ]
    ])

    expect(result).not_to be_success
    expect(result.errors.first).to include("Peso (kg)")
    expect(manifest.cargo_items.reload).to be_empty
  end
end

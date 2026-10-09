require "rails_helper"

RSpec.describe ContainerImporter do
  let(:master_bl) { create(:master_bl) }

  def import(rows, **options)
    described_class.new(master_bl, build_xlsx(rows, **options)).call
  end

  it "creates containers as activo linked to the MBL" do
    result = import([ [ "msku1234567", 20, "Estándar" ], [ "TGHU7654321", "40", "HQ" ] ])

    expect(result).to be_success
    expect(result.created).to eq(2)
    expect(master_bl.containers.order(:number).map(&:attributes).map { |a| a.slice("number", "size", "container_type", "status") }).to eq([
      { "number" => "MSKU1234567", "size" => 20, "container_type" => "standard", "status" => "activo" },
      { "number" => "TGHU7654321", "size" => 40, "container_type" => "hq", "status" => "activo" }
    ])
  end

  it "skips blank rows" do
    expect(import([ [ "MSKU1234567", 20, "HQ" ], [ nil, nil, nil ] ].reverse).created).to eq(1)
  end

  it "saves nothing and reports every invalid row" do
    result = import([ [ "MSKU1234567", 20, "HQ" ], [ "BAD", 20, "HQ" ], [ "TGHU7654321", 30, "HQ" ], [ "ABCD1234567", 20, "otro" ] ])

    expect(result).not_to be_success
    expect(result.errors.size).to eq(3)
    expect(result.errors.first).to start_with("Fila 3:")
    expect(Container.count).to eq(0)
  end

  it "rejects duplicates inside the file and against existing containers" do
    create(:container, number: "MSKU1234567")
    result = import([ [ "MSKU1234567", 20, "HQ" ], [ "TGHU7654321", 20, "HQ" ], [ "TGHU7654321", 20, "HQ" ] ])

    expect(result.errors.size).to eq(2)
    expect(Container.count).to eq(1)
  end

  it "rejects a missing file" do
    expect(described_class.new(master_bl, nil).call.errors).to eq([ I18n.t("container_import.errors.no_file") ])
  end

  it "rejects files that are not xlsx" do
    file = Rack::Test::UploadedFile.new(StringIO.new("a,b"), "text/csv", original_filename: "datos.csv")
    expect(described_class.new(master_bl, file).call.errors).to eq([ I18n.t("container_import.errors.invalid_file") ])
  end

  it "rejects corrupt xlsx files" do
    corrupt = Tempfile.new([ "corrupto", ".xlsx" ]).tap { |f| f.write("no es un zip"); f.flush }
    file = Rack::Test::UploadedFile.new(corrupt.path, ContainerSpreadsheet::CONTENT_TYPE, original_filename: "x.xlsx")
    expect(described_class.new(master_bl, file).call.errors).to eq([ I18n.t("container_import.errors.invalid_file") ])
  end

  it "rejects an empty sheet" do
    expect(import([]).errors).to eq([ I18n.t("container_import.errors.empty") ])
  end
end

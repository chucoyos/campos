require "rails_helper"

RSpec.describe CargoItemsHelper, type: :helper do
  describe "#packaging_quantity_label" do
    it "uses singular and plural forms for the standard packaging names" do
      { "Rollo" => "Rollos", "Caja" => "Cajas", "Pallet" => "Pallets" }.each do |singular, plural|
        packaging = build(:cargo_packaging, name: singular)
        expect(helper.packaging_quantity_label(packaging, 1)).to eq("1 #{singular}")
        expect(helper.packaging_quantity_label(packaging, 4)).to eq("4 #{plural}")
      end
    end

    it "retains custom catalog names without guessing their plural" do
      packaging = build(:cargo_packaging, name: "Saco industrial")
      expect(helper.packaging_quantity_label(packaging, 1)).to eq("1 unidad · Saco industrial")
      expect(helper.packaging_quantity_label(packaging, 4)).to eq("4 unidades · Saco industrial")
    end
  end
end

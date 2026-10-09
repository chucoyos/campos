require "rails_helper"

RSpec.describe Container, type: :model do
  subject { build(:container) }

  it { is_expected.to belong_to(:master_bl).optional }
  it { is_expected.to validate_presence_of(:number) }
  it { is_expected.to validate_uniqueness_of(:number).ignoring_case_sensitivity }
  it { is_expected.to validate_inclusion_of(:size).in_array([ 20, 40 ]) }
  it { is_expected.to define_enum_for(:container_type).with_values(standard: "standard", hq: "hq").backed_by_column_of_type(:string) }

  describe "number" do
    it "normalizes spaces, hyphens and case" do
      expect(build(:container, number: " msku 123456-7 ").number).to eq("MSKU1234567")
    end

    it "accepts 4 letters followed by 7 digits" do
      expect(build(:container, number: "MSKU1234567")).to be_valid
    end

    %w[MSK1234567 MSKU123456 MSKU12345678 1234MSKU567 MSKU12345A7].each do |invalid|
      it "rejects #{invalid}" do
        expect(build(:container, number: invalid)).not_to be_valid
      end
    end
  end

  describe "without MBL" do
    %w[lleno vacio].each do |status|
      it "can be created as #{status}" do
        expect(build(:container, status: status)).to be_valid
      end
    end

    %w[activo entregado].each do |status|
      it "cannot be #{status}" do
        expect(build(:container, status: status)).not_to be_valid
      end
    end

    it "has no available transitions" do
      container = create(:container, status: "lleno")
      expect(container.may_vaciar?).to be(false)
      expect { container.vaciar! }.to raise_error(AASM::InvalidTransition)
    end

    it "cannot be given an MBL later" do
      container = create(:container)
      expect(container.update(master_bl: create(:master_bl))).to be(false)
    end
  end

  describe "with MBL" do
    it "always starts as activo" do
      expect(create(:container, master_bl: create(:master_bl), status: "vacio")).to be_activo
    end

    it "follows activo -> lleno -> vacio -> entregado" do
      container = create(:container, :with_master_bl)
      container.llenar!
      expect(container).to be_lleno
      container.vaciar!
      expect(container).to be_vacio
      container.entregar!
      expect(container).to be_entregado
    end

    it "cannot skip steps" do
      container = create(:container, :with_master_bl)
      expect(container.may_vaciar?).to be(false)
      expect { container.vaciar! }.to raise_error(AASM::InvalidTransition)
      expect { container.entregar! }.to raise_error(AASM::InvalidTransition)
      expect(container.reload).to be_activo
    end

    it "does not leave entregado" do
      container = create(:container, :with_master_bl)
      container.llenar!
      container.vaciar!
      container.entregar!
      expect([ container.may_llenar?, container.may_vaciar?, container.may_entregar? ]).to all(be(false))
    end

    it "cannot lose its MBL" do
      container = create(:container, :with_master_bl)
      expect(container.update(master_bl: nil)).to be(false)
    end
  end
end

require "rails_helper"

RSpec.describe Client, type: :model do
  subject { build(:client) }

  it { is_expected.to have_many(:users).dependent(:nullify) }
  it { is_expected.to have_many(:master_bls).dependent(:restrict_with_error) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
  it { is_expected.to allow_value(nil, "#0ea5e9").for(:container_color) }
  it { is_expected.not_to allow_value("rojo", "#fff", "0ea5e9").for(:container_color) }

  it "normaliza el color vacío a nil y lo guarda en minúsculas" do
    expect(build(:client, container_color: "").container_color).to be_nil
    expect(build(:client, container_color: "#0EA5E9").container_color).to eq("#0ea5e9")
  end
end

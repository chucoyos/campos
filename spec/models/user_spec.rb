require "rails_helper"

RSpec.describe User, type: :model do
  subject { build(:user) }

  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  it { is_expected.to validate_presence_of(:role) }
  it { is_expected.to belong_to(:client).optional }
  it { is_expected.to belong_to(:carrier).optional }

  it "solo conserva el cliente si el rol es cliente" do
    client = create(:client)
    user = create(:user, :cliente, client: client)
    expect(user.client).to eq(client)

    user.update!(role: "transporte")
    expect(user.reload.client).to be_nil
  end

  it "solo conserva el transportista si el rol es transporte" do
    user = create(:user, :admin, carrier: create(:carrier))
    expect(user.reload.carrier).to be_nil
  end
  it { is_expected.to define_enum_for(:role).with_values(User::ROLES.index_with(&:itself)).backed_by_column_of_type(:string) }

  it "rejects invalid roles" do
    expect(build(:user, role: "otro")).not_to be_valid
  end
end

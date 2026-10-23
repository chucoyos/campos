require "rails_helper"

RSpec.describe User, type: :model do
  subject { build(:user) }

  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  it { is_expected.to validate_presence_of(:role) }
  it { is_expected.to belong_to(:client).optional }
  it { is_expected.to belong_to(:carrier).optional }

  it "permite cuentas externas con afiliación a cliente y transportista" do
    user = create(:user, :cliente, client: create(:client), carrier: create(:carrier))
    expect(user.reload).to be_client_member.and be_carrier_member
  end

  it "quita las afiliaciones a empresas en roles internos" do
    user = create(:user, :cliente, client: create(:client), carrier: create(:carrier))
    user.update!(role: "admin")
    user.reload
    expect([ user.client, user.carrier ]).to all(be_nil)
  end
  it { is_expected.to define_enum_for(:role).with_values(User::ROLES.index_with(&:itself)).backed_by_column_of_type(:string) }

  it "rejects invalid roles" do
    expect(build(:user, role: "otro")).not_to be_valid
  end
end

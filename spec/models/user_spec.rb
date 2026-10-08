require "rails_helper"

RSpec.describe User, type: :model do
  subject { build(:user) }

  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  it { is_expected.to validate_presence_of(:role) }
  it { is_expected.to define_enum_for(:role).with_values(User::ROLES.index_with(&:itself)).backed_by_column_of_type(:string) }

  it "rejects invalid roles" do
    expect(build(:user, role: "otro")).not_to be_valid
  end
end

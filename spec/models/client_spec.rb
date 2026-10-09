require "rails_helper"

RSpec.describe Client, type: :model do
  subject { build(:client) }

  it { is_expected.to belong_to(:user).optional }
  it { is_expected.to have_many(:master_bls).dependent(:restrict_with_error) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
end

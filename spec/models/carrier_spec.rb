require "rails_helper"

RSpec.describe Carrier, type: :model do
  subject { build(:carrier) }

  it { is_expected.to have_many(:users).dependent(:nullify) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
end

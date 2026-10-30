require "rails_helper"

RSpec.describe DeconsolidationPolicy do
  subject(:policy) { described_class.new(user, build(:deconsolidation)) }

  context "con administrador" do
    let(:user) { build(:user, :admin) }
    it { is_expected.to permit_action(:advance) }
  end

  %i[montacargas grua cliente].each do |role|
    context "con #{role}" do
      let(:user) { build(:user, role) }
      it { is_expected.to forbid_action(:index) }
    end
  end
end

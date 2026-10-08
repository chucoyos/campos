require "rails_helper"

RSpec.describe UserPolicy do
  subject { described_class.new(user, target) }

  let(:target) { build_stubbed(:user) }

  context "as admin" do
    let(:user) { build_stubbed(:user, :admin) }

    it { is_expected.to permit_actions(%i[index create update destroy]) }
  end

  context "as admin on themselves" do
    let(:user) { build_stubbed(:user, :admin) }
    let(:target) { user }

    it { is_expected.to forbid_action(:destroy) }
  end

  (User::ROLES - %w[admin]).each do |role|
    context "as #{role}" do
      let(:user) { build_stubbed(:user, role.to_sym) }

      it { is_expected.to forbid_actions(%i[index create update destroy]) }
    end
  end
end

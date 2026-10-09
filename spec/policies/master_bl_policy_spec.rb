require "rails_helper"

RSpec.describe MasterBlPolicy do
  subject { described_class.new(user, build_stubbed(:master_bl)) }

  context "as admin" do
    let(:user) { build_stubbed(:user, :admin) }

    it { is_expected.to permit_actions(%i[index show create update destroy]) }
  end

  (User::ROLES - %w[admin]).each do |role|
    context "as #{role}" do
      let(:user) { build_stubbed(:user, role.to_sym) }

      it { is_expected.to forbid_actions(%i[index show create update destroy]) }
    end
  end
end

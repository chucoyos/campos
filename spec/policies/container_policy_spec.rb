require "rails_helper"

RSpec.describe ContainerPolicy do
  subject { described_class.new(user, build_stubbed(:container)) }

  context "as admin" do
    let(:user) { build_stubbed(:user, :admin) }

    it { is_expected.to permit_actions(%i[index show create update destroy transition]) }
  end

  (User::ROLES - %w[admin]).each do |role|
    context "as #{role}" do
      let(:user) { build_stubbed(:user, role.to_sym) }

      it { is_expected.to forbid_actions(%i[index show create update destroy transition]) }
    end
  end
end

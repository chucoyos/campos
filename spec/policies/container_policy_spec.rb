require "rails_helper"

RSpec.describe ContainerPolicy do
  subject { described_class.new(user, build_stubbed(:container)) }

  context "as admin" do
    let(:user) { build_stubbed(:user, :admin) }

    it { is_expected.to permit_actions(%i[index show create update destroy transition photos upload_photos remove_photo]) }
  end

  context "as seguridad" do
    let(:user) { build_stubbed(:user, :seguridad) }

    it { is_expected.to permit_actions(%i[index show create update destroy photos upload_photos remove_photo]) }
    it { is_expected.to forbid_actions(%i[transition]) }
  end

  (User::ROLES - %w[admin seguridad]).each do |role|
    context "as #{role}" do
      let(:user) { build_stubbed(:user, role.to_sym) }

      it { is_expected.to forbid_actions(%i[index show create update destroy transition photos upload_photos remove_photo]) }
    end
  end
end

require "rails_helper"

RSpec.describe WorkOrderPolicy do
  subject(:policy) { described_class.new(user, order) }

  let(:order) { build_stubbed(:work_order) }

  context "con grúa" do
    let(:user) { build_stubbed(:user, :grua) }

    it { is_expected.to permit_actions(%i[index complete]) }
    it { is_expected.to forbid_action(:cancel) }
  end

  context "con admin" do
    let(:user) { build_stubbed(:user, :admin) }

    it { is_expected.to permit_actions(%i[index complete cancel]) }
  end

  %i[seguridad montacargas cliente transporte].each do |role|
    context "con #{role}" do
      let(:user) { build_stubbed(:user, role) }

      it { is_expected.to forbid_actions(%i[index complete cancel]) }
    end
  end

  it "no permite concluir una tarea ya cerrada" do
    closed = build_stubbed(:work_order, status: "completada")
    expect(described_class.new(build_stubbed(:user, :grua), closed)).to forbid_action(:complete)
  end
end

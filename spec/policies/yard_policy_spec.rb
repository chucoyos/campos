require "rails_helper"

RSpec.describe "Políticas del patio" do
  let(:slot) { build_stubbed(:yard_slot) }
  let(:area) { build_stubbed(:yard_area) }

  it "permite a admin y seguridad ver, y solo a admin modificar" do
    admin = build_stubbed(:user, :admin)
    guard = build_stubbed(:user, :seguridad)

    expect(YardSlotPolicy.new(admin, slot).toggle?).to be true
    expect(YardAreaPolicy.new(admin, area).update?).to be true
    expect(YardSlotPolicy.new(guard, slot).index?).to be true
    expect(YardSlotPolicy.new(guard, slot).toggle?).to be false
    expect(YardAreaPolicy.new(guard, area).update?).to be false
  end

  it "niega el acceso a los demás roles" do
    %i[cliente transporte grua montacargas].each do |role|
      user = build_stubbed(:user, role)
      expect(YardSlotPolicy.new(user, slot).index?).to be false
      expect(YardSlotPolicy.new(user, slot).toggle?).to be false
      expect(YardAreaPolicy.new(user, area).update?).to be false
    end
  end
end

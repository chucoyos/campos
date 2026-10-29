require "rails_helper"

RSpec.describe RehandlingRequest, type: :model do
  subject(:request) { create(:rehandling_request) }

  it { is_expected.to belong_to(:movement_pass) }
  it { is_expected.to belong_to(:container) }

  it "solo agrupa el pase de salida del contenedor objetivo" do
    pass = create(:movement_pass, :standalone, movement_type: "ingreso")
    invalid = build(:rehandling_request, movement_pass: pass)

    expect(invalid).not_to be_valid
  end

  it "permite completar o cancelar una solicitud pendiente" do
    request.completar!
    expect(request).to be_completada

    other = create(:rehandling_request)
    other.cancelar!
    expect(other).to be_cancelada
  end
end

require "rails_helper"

RSpec.describe Deconsolidation, type: :model do
  subject { create(:deconsolidation) }

  it { is_expected.to belong_to(:container) }
  it { is_expected.to validate_uniqueness_of(:container_id) }

  def attach_photo(container, section)
    container.public_send(:"#{section}_photos").attach(io: StringIO.new("x"), filename: "a.png", content_type: "image/png")
  end

  it "arranca en apertura y no avanza sin fotos de apertura" do
    expect(subject).to be_apertura
    expect(subject.may_iniciar_desconsolidacion?).to be(false)
    attach_photo(subject.container, "opening")
    expect(subject.may_iniciar_desconsolidacion?).to be(true)
    subject.iniciar_desconsolidacion!
    expect(subject).to be_desconsolidando
    expect(subject.started_at).to be_present
  end

  it "no pasa a la etapa de vacío con mercancía sin ubicar y no se vacía sin fotos" do
    manifest = create(:cargo_manifest, container: subject.container, client: subject.container.master_bl.client)
    create(:cargo_item, cargo_manifest: manifest)
    manifest.update_columns(status: "confirmed", confirmed_at: Time.current)
    attach_photo(subject.container, "opening")
    subject.iniciar_desconsolidacion!
    expect(subject.may_registrar_vacio?).to be(false)

    attach_photo(subject.container, "deconsolidation")
    expect(subject.reload.may_registrar_vacio?).to be(false)

    slot = create(:warehouse_slot)
    manifest.cargo_items.first.store_at!(slot, "A", nil)
    expect(subject.reload.may_registrar_vacio?).to be(true)
    subject.registrar_vacio!
    expect(subject.may_vaciar?).to be(false)

    attach_photo(subject.container, "empty")
    expect(subject.reload.may_vaciar?).to be(true)
  end
end

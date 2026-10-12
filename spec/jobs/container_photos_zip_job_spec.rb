require "rails_helper"

RSpec.describe ContainerPhotosZipJob, type: :job do
  let(:container) { create(:container, :with_master_bl) }
  let(:png) { Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==") }

  def attach_photo(name)
    container.opening_photos.attach(
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new(png), filename: name, content_type: "image/png")
    )
  end

  it "genera el ZIP, programa su borrado y avisa por Turbo Stream" do
    attach_photo("a.png")
    attach_photo("b.png")

    expect { described_class.perform_now(container.id, "opening", 7) }
      .to have_broadcasted_to("container_zip:#{container.id}:7:opening").at_least(:once)

    zip_blob = ActiveStorage::Blob.find_by(content_type: "application/zip")
    entries = []
    Zip::File.open_buffer(StringIO.new(zip_blob.download)) { |zip| entries = zip.map(&:name) }
    expect(entries).to eq(%w[001_a.png 002_b.png])
    expect(ActiveStorage::PurgeJob).to have_been_enqueued.with(zip_blob)
  end

  it "avisa del fallo cuando no hay fotos" do
    expect { described_class.perform_now(container.id, "opening", 7) }
      .to have_broadcasted_to("container_zip:#{container.id}:7:opening")
  end
end

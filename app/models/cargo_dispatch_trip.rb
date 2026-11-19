class CargoDispatchTrip < ApplicationRecord
  include AASM

  ORIGIN_TYPES = %w[mbl general].freeze
  TRANSPORT_MODES = %w[assigned customer].freeze

  belongs_to :cargo_dispatch_request, inverse_of: :trips
  belongs_to :carrier, optional: true
  belongs_to :created_by, class_name: "User"
  has_many :allocations, class_name: "CargoDispatchAllocation", dependent: :restrict_with_error, inverse_of: :cargo_dispatch_trip
  has_many :passes, class_name: "CargoDispatchPass", dependent: :restrict_with_error, inverse_of: :cargo_dispatch_trip
  has_many :events, class_name: "CargoDispatchEvent", dependent: :restrict_with_error, inverse_of: :cargo_dispatch_trip
  has_many_attached :exit_photos
  normalizes :transport_name, with: ->(value) { value.strip.presence }

  STREAM = "forklift_dispatches".freeze

  def exit_photos_zip_name(photos)
    digest = Digest::SHA256.hexdigest(photos.map(&:id).sort.join(","))
    "viaje-#{id}-salida-#{digest}.zip"
  end

  def ready_exit_photos_zip
    photos = exit_photos_attachments.order(:id).to_a
    return if photos.empty?

    ActiveStorage::Blob.where(filename: exit_photos_zip_name(photos), content_type: "application/zip")
      .where(created_at: ContainerPhotosZipJob::LINK_TTL.ago..).order(created_at: :desc).first
  end

  validates :origin_type, inclusion: { in: ORIGIN_TYPES }
  validates :transport_mode, inclusion: { in: TRANSPORT_MODES }
  validate :transport_matches_origin
  after_commit -> { Turbo::StreamsChannel.broadcast_refresh_to(STREAM) }, on: %i[create update]

  aasm column: :status, whiny_persistence: true, create_scopes: false do
    state :pending, initial: true
    state :prepared
    state :in_yard
    state :loaded
    state :completed
    state :cancelled

    event :prepare do
      transitions from: :pending, to: :prepared, guard: :ready_for_dispatch?
    end
    event :arrive do
      transitions from: :prepared, to: :in_yard
    end
    event :confirm_loading do
      transitions from: :in_yard, to: :loaded
    end
    event :finish do
      transitions from: :loaded, to: :completed
    end
    event :cancel do
      transitions from: %i[pending prepared], to: :cancelled
    end
  end

  private

  def transport_matches_origin
    errors.add(:transport_mode, :invalid) if transport_mode == "customer" && origin_type != "general"
    errors.add(:carrier, :invalid) if transport_mode == "customer" && carrier_id.present?
    errors.add(:transport_name, :invalid) if transport_mode == "assigned" && transport_name.present?
  end

  def ready_for_dispatch?
    allocations.where(status: "reserved").exists? &&
      (transport_mode == "assigned" ? carrier_id.present? : transport_name.present?)
  end
end

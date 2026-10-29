# Solicitud de ingreso, salida o traspaleo de un contenedor; los pases de ingreso y salida se validan en dos escaneos.
class MovementPass < ApplicationRecord
  include AASM

  MOVEMENT_TYPES = %w[ingreso salida traspaleo].freeze
  # Con MBL no hay traspaleo: ese movimiento es exclusivo del resguardo.
  MBL_MOVEMENT_TYPES = %w[ingreso salida].freeze
  VALIDITY = 48.hours

  belongs_to :container
  belongs_to :container_assignment, optional: true
  belongs_to :carrier, optional: true
  belongs_to :client, optional: true
  belongs_to :requested_by, class_name: "User", optional: true
  has_many :vehicles, class_name: "MovementPassVehicle", dependent: :destroy, inverse_of: :movement_pass
  has_one :movement, class_name: "ContainerMovement", dependent: :restrict_with_error
  has_one :rehandling_request, dependent: :restrict_with_error
  has_one :movement_plan, dependent: :restrict_with_error
  has_many_attached :photos

  accepts_nested_attributes_for :vehicles

  enum :movement_type, MOVEMENT_TYPES.index_with(&:itself), validate: true

  has_secure_token :token

  before_validation :set_defaults, on: :create
  before_validation :expire_overdue_for_container, on: :create
  after_commit :purge_photos_when_inactive, on: :update

  validates :load_status, inclusion: { in: Container::STANDALONE_STATUSES }, allow_nil: true
  validates :load_status, absence: true, if: -> { container&.with_master_bl? }
  validates :load_status, presence: true, if: -> { container && !container.with_master_bl? && ingreso? }
  validates :container_id, uniqueness: { scope: :movement_type, conditions: -> { where(status: "vigente") } }
  validate :assignment_matches_container, if: :container_assignment
  validate :standalone_requires_no_assignment
  validate :movement_allowed_for_container
  validate :vehicles_match_movement
  validate :photos_are_valid_images

  scope :active, -> { vigente.where("expires_at >= ? OR entered_at IS NOT NULL", Time.current) }
  scope :overdue, -> { vigente.where(entered_at: nil).where(expires_at: ...Time.current) }

  aasm column: :status do
    state :vigente, initial: true
    state :completado
    state :cancelado
    state :vencido

    event :completar, after: :use_assignment do
      transitions from: :vigente, to: :completado, guard: :usable?, after: -> { self.consumed_at = Time.current }
    end

    event :cancelar do
      transitions from: :vigente, to: :cancelado, guard: -> { entered_at.nil? },
        after: -> { self.cancelled_at = Time.current }
    end

    event :vencer do
      transitions from: :vigente, to: :vencido, guard: :expired?
    end
  end

  def expired? = entered_at.nil? && expires_at <= Time.current

  def usable? = vigente? && (entered_at.present? || !expired?)

  # Estado vigente en pantalla aunque nadie haya persistido aún el vencimiento.
  def display_status
    return "vencido" if vigente? && expired?
    return "en_patio" if vigente? && entered_at?

    status
  end

  def vehicle(role) = vehicles.find { |item| item.role == role }

  def with_master_bl? = container_assignment_id.present?

  def self.expire_overdue! = overdue.find_each(&:vencer!)

  private

  def set_defaults
    self.issued_at ||= Time.current
    self.expires_at ||= issued_at + VALIDITY
    self.client_id ||= container&.owner_client_id
    self.carrier_id ||= container_assignment&.carrier_id
  end

  def use_assignment
    container_assignment&.utilizar!
  end

  # Un pase vigente pero vencido no debe bloquear la emisión de uno nuevo.
  def expire_overdue_for_container
    self.class.overdue.where(container_id: container_id, movement_type: movement_type).find_each(&:vencer!)
  end

  def assignment_matches_container
    errors.add(:container_assignment, :mismatch) if container_assignment.container_id != container_id || container_assignment.operation != movement_type
    errors.add(:container_assignment, :not_pending) if new_record? && !container_assignment.pendiente?
  end

  def standalone_requires_no_assignment
    errors.add(:container_assignment, :required) if container&.with_master_bl? && container_assignment.blank?
  end

  def movement_allowed_for_container
    return unless container

    allowed = container.with_master_bl? ? MBL_MOVEMENT_TYPES : MOVEMENT_TYPES
    errors.add(:movement_type, :not_allowed) unless allowed.include?(movement_type)
  end

  def vehicles_match_movement
    active_vehicles = vehicles.reject(&:marked_for_destruction?)
    roles = active_vehicles.map(&:role)
    expected = movement_type == "traspaleo" ? MovementPassVehicle::ROLES : %w[principal]
    errors.add(:vehicles, :incomplete) unless roles.sort == expected.sort
  end

  def purge_photos_when_inactive
    photos.purge_later if saved_change_to_status? && (cancelado? || vencido?) && photos.attached?
  end

  def photos_are_valid_images
    return unless photos.attached?

    photos.each do |photo|
      errors.add(:photos, :invalid_type, filename: photo.filename) unless Container::PHOTO_CONTENT_TYPES.include?(photo.blob.content_type)
      errors.add(:photos, :too_large, filename: photo.filename, max: Container::PHOTO_MAX_SIZE / 1.megabyte) if photo.blob.byte_size > Container::PHOTO_MAX_SIZE
    end
    errors.add(:photos, :too_many, max: Container::MAX_PHOTOS_PER_UPLOAD) if photos.count > Container::MAX_PHOTOS_PER_UPLOAD
  end
end

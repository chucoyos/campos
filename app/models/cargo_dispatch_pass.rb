class CargoDispatchPass < ApplicationRecord
  include AASM

  VALIDITY = 48.hours
  belongs_to :cargo_dispatch_trip, inverse_of: :passes
  belongs_to :requested_by, class_name: "User"
  has_many :events, class_name: "CargoDispatchEvent", dependent: :restrict_with_error

  normalizes :operator_name, with: ->(value) { value.strip }
  normalizes :plate, with: ->(value) { value.gsub(/[\s-]/, "").upcase }
  normalizes :economic_number, with: ->(value) { value.strip.upcase }

  before_validation :set_defaults, on: :create
  validates :operator_name, :plate, :token, presence: true
  validates :unit_type, inclusion: { in: MovementPassVehicle::UNIT_TYPES }
  validates :token, uniqueness: true

  aasm column: :status, whiny_persistence: true, create_scopes: false do
    state :active, initial: true
    state :completed
    state :cancelled
    state :expired

    event :complete do
      transitions from: :active, to: :completed, after: -> { self.completed_at = Time.current }
    end
    event :cancel do
      transitions from: :active, to: :cancelled, guard: -> { entered_at.nil? }, after: -> { self.cancelled_at = Time.current }
    end
    event :expire do
      transitions from: :active, to: :expired, guard: :overdue?
    end
  end

  def overdue? = entered_at.nil? && expires_at <= Time.current
  def usable? = active? && (entered_at.present? || !overdue?)

  private

  def set_defaults
    self.token ||= "cargo_#{SecureRandom.urlsafe_base64(24)}"
    self.issued_at ||= Time.current
    self.expires_at ||= issued_at + VALIDITY
  end
end

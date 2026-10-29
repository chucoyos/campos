class MovementPlan < ApplicationRecord
  include AASM

  STREAM = "crane_work_orders".freeze
  TYPES = %w[salida reacomodo].freeze

  belongs_to :container
  belongs_to :movement_pass, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :origin_yard_slot, class_name: "YardSlot", optional: true
  belongs_to :destination_yard_slot, class_name: "YardSlot", optional: true
  has_one :rehandling_request, dependent: :restrict_with_error
  has_many :work_orders, dependent: :restrict_with_error

  validates :movement_type, inclusion: { in: TYPES }
  validates :container_id, uniqueness: { conditions: -> { where(status: "pendiente") } }, if: :pendiente?
  validates :movement_pass_id, uniqueness: true, allow_nil: true
  validates :origin_yard_slot, presence: true, if: :pendiente?
  validates :movement_pass, presence: true, if: :salida?
  validates :movement_pass, absence: true, if: :reacomodo?
  validates :destination_yard_slot, presence: true, if: :reacomodo?
  validate :pass_matches_target, if: :salida?

  after_commit :broadcast_changed

  aasm column: :status do
    state :pendiente, initial: true
    state :completada
    state :cancelada

    event :completar do
      transitions from: :pendiente, to: :completada
    end

    event :cancelar do
      transitions from: :pendiente, to: :cancelada
    end
  end

  def salida? = movement_type == "salida"
  def reacomodo? = movement_type == "reacomodo"

  def pending_target_order
    work_orders.find { |order| order.pendiente? && order.container_id == container_id && order.movement_type == movement_type }
  end

  def completed_rehandles
    work_orders.select { |order| order.reacomodo? && order.completada? && order.container_id != container_id }
  end

  private

  def pass_matches_target
    errors.add(:movement_pass, :mismatch) unless movement_pass&.salida? && movement_pass.container_id == container_id
  end

  def broadcast_changed
    Turbo::StreamsChannel.broadcast_refresh_to(STREAM)
  end
end

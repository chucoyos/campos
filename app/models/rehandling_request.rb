class RehandlingRequest < ApplicationRecord
  include AASM

  STREAM = "crane_work_orders".freeze

  belongs_to :movement_pass
  belongs_to :container
  belongs_to :created_by, class_name: "User", optional: true
  has_many :work_orders, dependent: :restrict_with_error

  validates :movement_pass_id, uniqueness: { conditions: -> { where(status: "pendiente") } }, if: :pendiente?
  validate :exit_pass_matches_target

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

  private

  def exit_pass_matches_target
    return unless movement_pass

    errors.add(:movement_pass, :mismatch) unless movement_pass.salida? && movement_pass.container_id == container_id
  end

  def broadcast_changed
    Turbo::StreamsChannel.broadcast_refresh_to(STREAM)
  end
end

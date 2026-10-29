# Lista de trabajo del administrador: contenedores que deben moverse del patio a DESYCON.
class WorkSchedule < ApplicationRecord
  include AASM

  belongs_to :master_bl, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  has_many :work_orders, dependent: :restrict_with_error
  has_many :movement_plans, dependent: :restrict_with_error

  validates :scheduled_for, presence: true

  after_commit -> { Turbo::StreamsChannel.broadcast_refresh_to(WorkOrder::STREAM) }

  aasm column: :status do
    state :activa, initial: true
    state :completada
    state :cancelada

    event :completar do
      transitions from: :activa, to: :completada
    end

    event :cancelar do
      transitions from: :activa, to: :cancelada
    end
  end

  def pending_work_orders = work_orders.where(status: "pendiente")
  def pending_movement_plans = movement_plans.where(status: "pendiente")

  def finished?
    !pending_work_orders.exists? && !pending_movement_plans.exists?
  end
end

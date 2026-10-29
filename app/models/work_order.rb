# Tarea operativa para la grúa; hoy solo se genera al ingresar un contenedor por Garita.
class WorkOrder < ApplicationRecord
  include AASM

  STREAM = "crane_work_orders".freeze

  belongs_to :container
  belongs_to :movement_pass, optional: true
  belongs_to :from_yard_slot, class_name: "YardSlot", optional: true
  belongs_to :to_yard_slot, class_name: "YardSlot", optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :completed_by, class_name: "User", optional: true

  enum :movement_type, ContainerMovement::TYPES.index_with(&:itself), validate: true

  validates :container_id, uniqueness: { conditions: -> { where(status: "pendiente") } }, if: :pendiente?
  validates :to_yard_slot, presence: true, if: :ingreso?

  after_commit :broadcast_changed, on: %i[create update]

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

  # El refresco evita enviar HTML con tokens CSRF; cada cliente recarga su propia vista.
  def broadcast_changed
    Turbo::StreamsChannel.broadcast_refresh_to(STREAM)
  end
end

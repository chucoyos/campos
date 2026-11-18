class CargoDispatchInstruction < ApplicationRecord
  CRITERIA = %w[all half quantity weight].freeze

  belongs_to :cargo_dispatch_request, inverse_of: :instructions
  belongs_to :container, optional: true
  belongs_to :cargo_packaging, optional: true
  has_many :allocations, class_name: "CargoDispatchAllocation", dependent: :restrict_with_error
  has_many :container_preferences, class_name: "CargoDispatchInstructionContainer",
    dependent: :destroy, inverse_of: :cargo_dispatch_instruction
  has_many :preferred_containers, through: :container_preferences, source: :container

  validates :criterion, inclusion: { in: CRITERIA }
  validates :container, presence: true, if: -> { %w[all half].include?(criterion) }
  validates :cargo_packaging, presence: true, if: -> { criterion == "quantity" }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }, if: -> { criterion == "quantity" }
  validates :weight_kg, numericality: { greater_than: 0 }, if: -> { criterion == "weight" }
  validate :container_belongs_to_client

  private

  def container_belongs_to_client
    return unless container && cargo_dispatch_request
    return if container.master_bl&.client_id == cargo_dispatch_request.client_id

    errors.add(:container, :invalid)
  end
end

class CargoDispatchInstructionContainer < ApplicationRecord
  belongs_to :cargo_dispatch_instruction, inverse_of: :container_preferences
  belongs_to :container

  validates :container_id, uniqueness: { scope: :cargo_dispatch_instruction_id }
  validate :container_belongs_to_request_client

  private

  def container_belongs_to_request_client
    request_client_id = cargo_dispatch_instruction&.cargo_dispatch_request&.client_id
    return unless container_id && request_client_id
    return if Container.joins(:master_bl).exists?(id: container_id, master_bls: { client_id: request_client_id })

    errors.add(:container, :invalid)
  end
end

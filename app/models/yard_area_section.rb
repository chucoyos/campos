# Agrupación de posiciones dentro de un área; puede vincularse a un MBL del cliente del área.
class YardAreaSection < ApplicationRecord
  belongs_to :yard_area
  belongs_to :master_bl, optional: true
  has_many :yard_slots, dependent: :nullify

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, uniqueness: { scope: :yard_area_id }
  validate :master_bl_belongs_to_area_client

  scope :active, -> { where(active: true) }

  # Asigna posiciones del bloque del área; una posición solo pertenece a una sección activa.
  def assign_slots(bays:, rows:, levels:)
    candidates = yard_area.yard_block.yard_slots.where(bay: bays, row: rows, level: levels)
    free = candidates.where(yard_area_section_id: nil)
                     .or(candidates.where(yard_area_section_id: YardAreaSection.where(active: false).select(:id)))
                     .or(candidates.where(yard_area_section_id: id))
    assigned = free.update_all(yard_area_section_id: id, updated_at: Time.current)
    { assigned: assigned, conflicts: candidates.count - free.count }
  end

  def release_slots(bays:, rows:, levels:)
    yard_slots.where(bay: bays, row: rows, level: levels).update_all(yard_area_section_id: nil, updated_at: Time.current)
  end

  private

  def master_bl_belongs_to_area_client
    return if master_bl.nil?

    errors.add(:master_bl, :wrong_client) if yard_area&.client_id.nil? || master_bl.client_id != yard_area.client_id
  end
end

# Asignación interna de un contenedor con MBL a un transportista para una operación (ingreso o salida).
class ContainerAssignment < ApplicationRecord
  include AASM

  OPERATIONS = %w[ingreso salida].freeze

  belongs_to :container
  belongs_to :carrier
  belongs_to :assigned_by, class_name: "User", optional: true
  belongs_to :yard_area, optional: true
  belongs_to :yard_area_section, optional: true

  enum :operation, OPERATIONS.index_with(&:itself), validate: true

  before_validation :derive_area_from_section

  validates :preferred_level, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :container_id, uniqueness: { scope: :operation, conditions: -> { where(status: "pendiente") } }
  validate :container_has_master_bl
  validate :area_is_active_and_matches_client
  validate :section_belongs_to_area
  validate :level_within_block

  scope :open, -> { where(status: "pendiente") }

  aasm column: :status do
    state :pendiente, initial: true
    state :utilizada
    state :cancelada

    event :utilizar do
      transitions from: :pendiente, to: :utilizada
    end

    event :cancelar do
      transitions from: :pendiente, to: :cancelada
    end
  end

  private

  def derive_area_from_section
    self.yard_area ||= yard_area_section&.yard_area
  end

  def container_has_master_bl
    errors.add(:container, :without_master_bl) if container && !container.with_master_bl?
  end

  def area_is_active_and_matches_client
    return unless yard_area

    errors.add(:yard_area, :inactive) unless yard_area.active?
    return unless container&.with_master_bl? && yard_area.client_id

    errors.add(:yard_area, :wrong_client) if yard_area.client_id != container.master_bl.client_id
  end

  def section_belongs_to_area
    return unless yard_area_section

    errors.add(:yard_area_section, :wrong_area) if yard_area_section.yard_area_id != yard_area_id
    errors.add(:yard_area_section, :inactive) unless yard_area_section.active?
    return unless container&.with_master_bl? && yard_area_section.master_bl_id

    errors.add(:yard_area_section, :wrong_master_bl) if yard_area_section.master_bl_id != container.master_bl_id
  end

  def level_within_block
    return unless preferred_level && yard_area

    errors.add(:preferred_level, :out_of_block) if preferred_level > yard_area.yard_block.levels
  end
end

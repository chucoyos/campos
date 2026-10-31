# Historial inmutable de los movimientos físicos de un contenedor.
class ContainerMovement < ApplicationRecord
  TYPES = %w[ingreso salida traspaleo reacomodo].freeze

  belongs_to :container
  belongs_to :movement_pass, optional: true
  belongs_to :from_yard_slot, class_name: "YardSlot", optional: true
  belongs_to :to_yard_slot, class_name: "YardSlot", optional: true
  belongs_to :user, optional: true
  has_many_attached :photos
  has_many_attached :exit_photos

  validates :movement_type, inclusion: { in: TYPES }
  validates :load_status, inclusion: { in: Container::STANDALONE_STATUSES }, allow_nil: true
  validate :positions_match_movement
  validate :pass_matches_movement
  validate :pass_presence
  validate :photos_are_valid_images

  before_update :prevent_modification
  before_destroy :prevent_modification

  private

  def positions_match_movement
    valid_positions = case movement_type
    when "ingreso" then from_yard_slot_id.nil? && to_yard_slot_id.present?
    when "salida" then from_yard_slot_id.present? && to_yard_slot_id.nil?
    when "traspaleo" then from_yard_slot_id.nil? && to_yard_slot_id.nil?
    when "reacomodo" then from_yard_slot_id.present? && to_yard_slot_id.present?
    end
    errors.add(:base, :invalid_positions) unless valid_positions
  end

  def pass_matches_movement
    return if movement_type == "reacomodo" && movement_pass.nil?
    return unless movement_pass

    errors.add(:movement_pass, :mismatch) if movement_pass.container_id != container_id || movement_pass.movement_type != movement_type
  end

  def pass_presence
    errors.add(:movement_pass, :required) if movement_type != "reacomodo" && movement_pass.nil?
  end

  def photos_are_valid_images
    %i[photos exit_photos].each do |name|
      attachments = public_send(name)
      next unless attachments.attached?

      attachments.each do |photo|
        errors.add(name, :invalid_type, filename: photo.filename) unless Container::PHOTO_CONTENT_TYPES.include?(photo.blob.content_type)
        errors.add(name, :too_large, filename: photo.filename, max: Container::PHOTO_MAX_SIZE / 1.megabyte) if photo.blob.byte_size > Container::PHOTO_MAX_SIZE
      end
      errors.add(name, :too_many, max: Container::MAX_PHOTOS_PER_UPLOAD) if attachments.count > Container::MAX_PHOTOS_PER_UPLOAD
    end
  end

  def prevent_modification
    errors.add(:base, :immutable)
    throw :abort
  end
end

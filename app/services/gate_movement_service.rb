require "set"

class GateMovementService
  class Error < StandardError
    attr_reader :key

    def initialize(key)
      @key = key
      super(I18n.t("gate.errors.#{key}"))
    end
  end

  def self.call(pass:, user:, yard_slot_id: nil)
    new(pass:, user:, yard_slot_id:).call
  end

  def self.suggested_slot(pass)
    available_slots(pass.container, pass:).first
  end

  def self.available_slots(container, pass: nil)
    available_slot_records(container, pass:).map { |slot| slot[:slot] }
  end

  def self.available_slot_records(container, pass: nil)
    sources = preferred_slot_sources(container, pass)
    preferred = sources.keys
    enabled_slots = YardSlot.enabled.joins(:yard_block).merge(YardBlock.enabled)
      .includes(:yard_block, yard_area_section: :yard_area).order(:yard_block_id, :bay, :row, :level).to_a
    slots_by_id = enabled_slots.index_by(&:id)
    slots_by_position = enabled_slots.index_by { |slot| position_key(slot) }
    ordered = preferred.filter_map { |id| slots_by_id.delete(id) } + slots_by_id.values

    block_ids = ordered.map(&:yard_block_id).uniq
    occupied_by_block = Hash.new { |hash, key| hash[key] = Set.new }
    Container.where.not(current_yard_slot_id: nil).joins(:current_yard_slot)
      .where(yard_slots: { yard_block_id: block_ids }).includes(:current_yard_slot).each do |occupant|
        occupied_footprint(occupant).each do |position|
          occupied_by_block[position.first] << position
        end
      end

    available = ordered.select do |slot|
      footprint = footprint_for(container, slot, slots_by_position:)
      footprint && (footprint & occupied_by_block[slot.yard_block_id].to_a).empty?
    end
    available.map do |slot|
      { slot: slot, source: sources[slot.id] || "yard" }
    end
  end

  def self.preferred_slot_ids(container, pass)
    preferred_slot_sources(container, pass).keys
  end

  def self.preferred_slot_sources(container, pass)
    groups = []
    sources = {}
    assignment = pass&.container_assignment

    if assignment
      preferred_scope = if assignment.yard_area_section
        YardSlot.joins(yard_area_section: :yard_area)
          .merge(YardAreaSection.active).merge(YardArea.active)
          .where(yard_area_section_id: assignment.yard_area_section_id)
      elsif assignment.yard_area
        YardSlot.joins(yard_area_section: :yard_area)
          .merge(YardAreaSection.active).merge(YardArea.active)
          .where(yard_area_sections: { yard_area_id: assignment.yard_area_id })
      end
      if preferred_scope
        preferred_slots = preferred_scope.where(enabled: true)
        if assignment.preferred_level
          groups << [ "assignment", preferred_slots.where(level: assignment.preferred_level).order(:bay, :row, :level).pluck(:id) ]
        end
        groups << [ "assignment", preferred_slots.order(:bay, :row, :level).pluck(:id) ]
      end
    end

    if container.with_master_bl?
      groups << [ "master_bl", YardSlot.enabled.joins(yard_area_section: :yard_area)
        .merge(YardAreaSection.active).merge(YardArea.active)
        .where(yard_area_sections: { master_bl_id: container.master_bl_id })
        .order(:yard_block_id, :bay, :row, :level).pluck(:id) ]
    end

    if container.owner_client_id
      groups << [ "client", YardSlot.enabled.joins(yard_area_section: :yard_area)
        .merge(YardAreaSection.active).merge(YardArea.active)
        .where(yard_areas: { client_id: container.owner_client_id })
        .order(:yard_block_id, :bay, :row, :level).pluck(:id) ]
    end

    groups.each do |source, ids|
      ids.each { |id| sources[id] ||= source }
    end
    sources
  end

  def self.compatible_and_free?(container, slot)
    footprint = footprint_for(container, slot)
    return false unless footprint

    occupied = Container.where.not(current_yard_slot_id: nil)
      .joins(:current_yard_slot)
      .where(yard_slots: { yard_block_id: slot.yard_block_id })
      .includes(:current_yard_slot)
      .flat_map { |occupant| occupied_footprint(occupant) }.to_set
    (footprint & occupied.to_a).empty?
  end

  def self.footprint_for(container, anchor, require_enabled: true, slots_by_position: nil)
    return unless anchor
    return if require_enabled && (!anchor.enabled? || !anchor.yard_block&.enabled?)

    if container.size.to_i == 40
      return unless anchor.forty_foot_anchor?

      companion_position = [ anchor.yard_block_id, anchor.bay + 1, anchor.row, anchor.level ]
      companion = if slots_by_position
        slots_by_position[companion_position]
      else
        YardSlot.find_by(
          yard_block_id: anchor.yard_block_id,
          bay: anchor.bay + 1,
          row: anchor.row,
          level: anchor.level,
          **(require_enabled ? { enabled: true } : {})
        )
      end
      return [ position_key(anchor) ] if companion.nil? && !require_enabled
      return unless companion

      [ position_key(anchor), position_key(companion) ]
    else
      [ position_key(anchor) ]
    end
  end

  def self.occupied_footprint(container)
    anchor = container.current_yard_slot
    return [] unless anchor

    return [ position_key(anchor), [ anchor.yard_block_id, anchor.bay + 1, anchor.row, anchor.level ] ] if container.size.to_i == 40

    [ position_key(anchor) ]
  end

  def self.position_key(slot)
    [ slot.yard_block_id, slot.bay, slot.row, slot.level ]
  end

  def call
    Container.transaction do
      @pass = MovementPass.lock.find(@pass.id)
      @container = Container.lock.find(@pass.container_id)
      raise Error, :pass_unusable unless @pass.usable?
      validate_assignment

      case @pass.movement_type
      when "ingreso" then record_entry
      when "salida" then record_exit
      when "traspaleo" then record_transfer
      else raise Error, :invalid_movement
      end

      @pass.consumed_at ||= Time.current
      @pass.completar!
      @pass
    end
  end

  private

  def initialize(pass:, user:, yard_slot_id:)
    @pass = pass
    @user = user
    @yard_slot_id = yard_slot_id
  end

  def record_entry
    raise Error, :already_in_yard if @container.current_yard_slot_id.present?
    raise Error, :location_required if @yard_slot_id.blank?

    slot = YardSlot.find_by(id: @yard_slot_id)
    raise Error, :location_unavailable unless slot

    footprint = lock_footprint(slot)
    raise Error, :location_unavailable unless footprint
    raise Error, :location_occupied unless self.class.compatible_and_free?(@container, slot)

    @container.current_yard_slot = slot
    update_standalone_load_status
    @container.save!
    create_movement(from: nil, to: slot)
  end

  def validate_assignment
    return unless @pass.container_assignment

    assignment = ContainerAssignment.lock.find(@pass.container_assignment_id)
    raise Error, :assignment_not_pending unless assignment.pendiente?
  end

  def record_exit
    slot = @container.current_yard_slot
    raise Error, :not_in_yard unless slot

    footprint = lock_footprint(slot, require_enabled: false)
    raise Error, :location_unavailable unless footprint
    @container.current_yard_slot = nil
    update_standalone_load_status
    @container.save!
    create_movement(from: slot, to: nil)
  end

  def record_transfer
    raise Error, :already_in_yard if @container.current_yard_slot_id.present?

    update_standalone_load_status
    @container.save! if @container.changed?
    create_movement(from: nil, to: nil)
  end

  def lock_footprint(anchor, require_enabled: true)
    positions = self.class.footprint_for(@container, anchor, require_enabled:)
    return unless positions

    ids = positions.map do |block_id, bay, row, level|
      YardSlot.find_by(yard_block_id: block_id, bay:, row:, level:)&.id
    end
    return if ids.first.nil?

    ids.compact!
    slots = YardSlot.where(id: ids).order(:id).lock.to_a
    return unless slots.size == ids.size
    return if require_enabled && slots.any? { |position| !position.enabled? || !position.yard_block.enabled? }

    slots
  end

  def update_standalone_load_status
    return if @container.with_master_bl? || @pass.load_status.blank?

    @container.declare_load_status!(@pass.load_status)
  end

  def create_movement(from:, to:)
    movement = ContainerMovement.create!(
      container: @container,
      movement_pass: @pass,
      from_yard_slot: from,
      to_yard_slot: to,
      user: @user,
      movement_type: @pass.movement_type,
      load_status: @pass.load_status,
      created_at: Time.current
    )
    if @pass.photos.attached?
      @pass.photos.blobs.each do |blob|
        ActiveStorage::Attachment.create!(name: "photos", record: movement, blob:)
      end
    end
    @pass.photos.detach if @pass.photos.attached?
    movement
  end
end

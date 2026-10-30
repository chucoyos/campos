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

  # Por defecto solo devuelve posiciones del área/sección del cliente/MBL y nunca DESYCON;
  # `desycon: true` devuelve únicamente DESYCON (programación de desconsolidación).
  def self.available_slots(container, pass: nil, except_work_order_id: nil, except_movement_plan_id: nil, desycon: false)
    available_slot_records(container, pass:, except_work_order_id:, except_movement_plan_id:, desycon:).map { |slot| slot[:slot] }
  end

  def self.allowed_destination?(container, slot, desycon: false, pass: nil, assignment: assignment_for(container, pass))
    return slot.desycon? if desycon

    !slot.desycon? && owner_destination?(container, slot) && within_assignment?(assignment, slot)
  end

  # La asignación del pase manda; sin pase se usa la última de ingreso con área definida.
  def self.assignment_for(container, pass = nil)
    pass&.container_assignment ||
      container.assignments.where(operation: "ingreso").where.not(yard_area_id: nil).order(:id).last
  end

  def self.within_assignment?(assignment, slot)
    return true unless assignment&.yard_area_id

    section = slot.yard_area_section
    return section&.id == assignment.yard_area_section_id if assignment.yard_area_section_id

    section&.yard_area_id == assignment.yard_area_id
  end

  # Una sección reservada a un MBL solo admite ese MBL; un área de cliente, solo ese cliente.
  def self.owner_destination?(container, slot)
    section = slot.yard_area_section
    return section.master_bl_id == container.master_bl_id if section&.master_bl_id

    client_id = section&.yard_area&.client_id
    client_id.nil? || client_id == container.owner_client_id
  end

  def self.available_slot_records(container, pass: nil, except_work_order_id: nil, except_movement_plan_id: nil, desycon: false)
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

    reserved_by_block = Hash.new { |hash, key| hash[key] = Set.new }
    reserved_positions(block_ids, except_work_order_id:, except_movement_plan_id:).each do |position|
      reserved_by_block[position.first] << position
    end

    assignment = assignment_for(container, pass)
    available = ordered.select do |slot|
      next false unless allowed_destination?(container, slot, desycon:, assignment:)

      footprint = footprint_for(container, slot, slots_by_position:)
      footprint && free_and_supported?(footprint, occupied_by_block[slot.yard_block_id], reserved_by_block[slot.yard_block_id])
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

    taken = occupied_positions(slot.yard_block_id) | reserved_positions(slot.yard_block_id)
    footprint.none? { |position| taken.include?(position) }
  end

  def self.supported?(container, slot)
    footprint = footprint_for(container, slot)
    footprint.present? && supported_footprint?(footprint, occupied_positions(slot.yard_block_id))
  end

  def self.occupied_positions(block_id)
    Container.where.not(current_yard_slot_id: nil)
      .joins(:current_yard_slot)
      .where(yard_slots: { yard_block_id: block_id })
      .includes(:current_yard_slot)
      .flat_map { |occupant| occupied_footprint(occupant) }.to_set
  end

  # Destinos de órdenes de grúa pendientes: bloquean la posición, pero aún no sirven de soporte.
  def self.reserved_positions(block_ids, except_work_order_id: nil, except_movement_plan_id: nil)
    scope = WorkOrder.where(status: "pendiente").where.not(to_yard_slot_id: nil)
    scope = scope.where.not(id: except_work_order_id) if except_work_order_id
    work_order_positions = scope
      .joins(:to_yard_slot).where(yard_slots: { yard_block_id: block_ids })
      .includes(:container, :to_yard_slot).flat_map do |order|
        footprint_for(order.container, order.to_yard_slot, require_enabled: false) || []
      end.to_set
    plan_scope = MovementPlan.where(status: "pendiente", movement_type: "reacomodo")
      .where.not(destination_yard_slot_id: nil)
    plan_scope = plan_scope.where.not(id: except_movement_plan_id) if except_movement_plan_id
    plan_positions = plan_scope
      .joins(:destination_yard_slot).where(yard_slots: { yard_block_id: block_ids })
      .includes(:container, :destination_yard_slot).flat_map do |plan|
        footprint_for(plan.container, plan.destination_yard_slot, require_enabled: false) || []
      end.to_set
    work_order_positions | plan_positions
  end

  # Un nivel superior solo es válido si cada posición de la huella tiene un contenedor debajo.
  def self.supported_footprint?(footprint, occupied)
    footprint.all? do |block_id, bay, row, level|
      level <= 1 || occupied.include?([ block_id, bay, row, level - 1 ])
    end
  end

  def self.free_and_supported?(footprint, occupied, reserved = Set.new)
    footprint.none? { |position| occupied.include?(position) || reserved.include?(position) } &&
      supported_footprint?(footprint, occupied)
  end

  def self.supporting_other?(container, except_work_order_id: nil)
    anchor = container.current_yard_slot
    return false unless anchor

    above = occupied_footprint(container).map { |block_id, bay, row, level| [ block_id, bay, row, level + 1 ] }
    return true if (reserved_positions(anchor.yard_block_id, except_work_order_id:).to_a & above).any?

    Container.where.not(id: container.id).where.not(current_yard_slot_id: nil)
      .joins(:current_yard_slot).where(yard_slots: { yard_block_id: anchor.yard_block_id })
      .includes(:current_yard_slot).any? do |other|
        (occupied_footprint(other) & above).any?
      end
  end

  def self.blocking_containers(container)
    anchor = container.current_yard_slot
    return [] unless anchor

    target_footprint = occupied_footprint(container)
    target_columns = target_footprint.map { |block_id, bay, row, _level| [ block_id, bay, row ] }.to_set
    candidates = Container.where.not(id: container.id).where.not(current_yard_slot_id: nil)
      .joins(:current_yard_slot).where(yard_slots: { yard_block_id: anchor.yard_block_id })
      .includes(:current_yard_slot).to_a
    candidates.select do |occupant|
      occupied_footprint(occupant).any? do |block_id, bay, row, level|
        level > anchor.level && target_columns.include?([ block_id, bay, row ])
      end
    end
  end

  def self.next_rehandle_candidate(container)
    blocking_containers(container)
      .reject { |blocker| supporting_other?(blocker) }
      .max_by { |blocker| blocker.current_yard_slot.level }
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

      if @pass.entered_at?
        complete_gate_exit
      else
        raise Error, :entry_pending if WorkOrder.where(container_id: @container.id, status: "pendiente").exists?
        validate_assignment

        case @pass.movement_type
        when "ingreso" then record_entry
        when "salida" then MovementPlanService.start_exit(pass: @pass, user: @user)
        when "traspaleo" then record_transfer
        else raise Error, :invalid_movement
        end

        if @pass.traspaleo?
          @pass.consumed_at ||= Time.current
          @pass.completar!
        else
          @pass.update!(entered_at: Time.current)
        end
      end
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
    raise Error, :location_not_allowed unless self.class.allowed_destination?(@container, slot, pass: @pass)
    raise Error, :location_unsupported unless self.class.supported?(@container, slot)

    WorkOrder.create!(
      container: @container,
      movement_pass: @pass,
      movement_type: "ingreso",
      to_yard_slot: slot,
      created_by: @user
    )
  end

  def validate_assignment
    return unless @pass.container_assignment

    assignment = ContainerAssignment.lock.find(@pass.container_assignment_id)
    raise Error, :assignment_not_pending unless assignment.pendiente?
  end

  def complete_gate_exit
    raise Error, :exit_scan_required unless @pass.exit_scanned_at?

    pass_canceled_without_load = @pass.movement_plan&.cancelada? && @pass.movement.nil?
    raise Error, :movement_not_completed unless @pass.movement || pass_canceled_without_load

    @pass.consumed_at ||= Time.current
    @pass.completar!
    @pass
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

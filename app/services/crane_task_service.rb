class CraneTaskService
  class Error < StandardError
    def initialize(key)
      super(I18n.t("crane.errors.#{key}"))
    end
  end

  def self.complete(work_order:, user:, yard_slot_id: nil)
    new(work_order, user, yard_slot_id).complete
  end

  def initialize(work_order, user, yard_slot_id)
    @work_order = work_order
    @user = user
    @yard_slot_id = yard_slot_id
  end

  def complete
    WorkOrder.transaction do
      @work_order = WorkOrder.lock.find(@work_order.id)
      raise Error, :not_pending unless @work_order.pendiente?

      @container = Container.lock.find(@work_order.container_id)
      @pass = @work_order.movement_pass

      case @work_order.movement_type
      when "ingreso" then complete_entry
      when "salida" then complete_exit
      when "reacomodo" then complete_rehandle
      else raise Error, :invalid_movement
      end

      @work_order.completed_by = @user
      @work_order.completed_at = Time.current
      @work_order.completar!

      complete_movement_plan if movement_plan_target_order?
      WorkScheduleService.close_if_finished(@work_order.work_schedule)
      MovementPlanService.advance_pending if @work_order.salida? || @work_order.reacomodo?
      @work_order
    end
  end

  private

  def complete_entry
    slot = @work_order.to_yard_slot
    raise Error, :already_in_yard if @container.current_yard_slot_id.present?

    validate_destination(slot)
    @container.current_yard_slot = slot
    @container.declare_load_status!(@pass.load_status) if standalone_load_status?
    @container.llenar! if @container.may_llenar?
    @container.save!
    create_movement(from: nil, to: slot)
  end

  def complete_exit
    slot = @container.current_yard_slot
    raise Error, :not_in_yard unless slot
    raise Error, :origin_changed unless @work_order.from_yard_slot_id == slot.id
    lock_block_slots(slot)
    raise Error, :supports_other_container if GateMovementService.supporting_other?(@container)
    if @work_order.movement_plan && GateMovementService.blocking_containers(@container).any?
      raise Error, :container_still_blocked
    end

    @container.current_yard_slot = nil
    update_standalone_load_status
    @container.entregar! if @container.may_entregar?
    @container.save!
    create_movement(from: slot, to: nil)
  end

  def complete_rehandle
    origin = @container.current_yard_slot
    raise Error, :not_in_yard unless origin
    raise Error, :origin_changed unless @work_order.from_yard_slot_id == origin.id

    destination = YardSlot.find_by(id: @yard_slot_id.presence || @work_order.to_yard_slot_id)
    raise Error, :destination_unavailable unless destination
    raise Error, :destination_unchanged if destination.id == origin.id
    raise Error, :destination_not_desycon if @work_order.work_schedule_id && !destination.desycon?

    lock_block_slots(origin, destination)
    raise Error, :supports_other_container if GateMovementService.supporting_other?(
      @container, except_work_order_id: @work_order.id
    )
    validate_destination(destination)
    @container.current_yard_slot = destination
    @container.save!
    create_movement(from: origin, to: destination)
    @work_order.to_yard_slot = destination
  end

  def validate_destination(slot)
    footprint = GateMovementService.footprint_for(@container, slot)
    raise Error, :destination_unavailable unless footprint

    lock_block_slots(slot)
    occupied = GateMovementService.occupied_positions(slot.yard_block_id)
    raise Error, :destination_occupied if footprint.any? { |position| occupied.include?(position) }
    reserved = GateMovementService.reserved_positions(
      slot.yard_block_id,
      except_work_order_id: @work_order.id,
      except_movement_plan_id: @work_order.movement_plan_id
    )
    raise Error, :destination_occupied if footprint.any? { |position| reserved.include?(position) }
    raise Error, :destination_unsupported unless GateMovementService.supported_footprint?(footprint, occupied)
  end

  def lock_block_slots(*slots)
    YardSlot.where(yard_block_id: slots.map(&:yard_block_id).uniq).order(:id).lock.pluck(:id)
  end

  def standalone_load_status?
    !@container.with_master_bl? && @pass&.load_status.present?
  end

  def update_standalone_load_status
    return if @container.with_master_bl? || @pass&.load_status.blank?

    @container.declare_load_status!(@pass.load_status)
  end

  def create_movement(from:, to:)
    movement = ContainerMovement.create!(
      container: @container,
      movement_pass: @pass,
      from_yard_slot: from,
      to_yard_slot: to,
      user: @user,
      movement_type: @work_order.movement_type,
      load_status: @pass&.load_status,
      created_at: Time.current
    )
    return movement unless @pass&.photos&.attached?

    @pass.photos.blobs.each do |blob|
      ActiveStorage::Attachment.create!(name: "photos", record: movement, blob:)
    end
    @pass.photos.detach
    movement
  end

  def movement_plan_target_order?
    plan = @work_order.movement_plan
    plan && @work_order.container_id == plan.container_id && @work_order.movement_type == plan.movement_type
  end

  def complete_movement_plan
    plan = @work_order.movement_plan
    plan.completar! if plan.pendiente?
    request = plan.rehandling_request
    request.completar! if request&.pendiente?
  end
end

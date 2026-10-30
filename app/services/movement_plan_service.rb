class MovementPlanService
  class Error < StandardError
    attr_reader :key

    def initialize(key)
      @key = key
      super(I18n.t("crane.errors.#{key}"))
    end
  end

  def self.start_exit(pass:, user:)
    new(user:).start_exit(pass)
  end

  def self.advance(plan)
    new(user: plan.created_by).advance(plan)
  end

  def self.advance_pending
    MovementPlan.where(status: "pendiente").find_each do |plan|
      new(user: plan.created_by).advance(plan)
    end
  end

  def self.create_independent(container:, user:, destination_id:)
    new(user:).create_independent(container:, destination_id:)
  end

  def self.cancel(plan:, user:)
    new(user:).cancel(plan)
  end

  def self.update_destination(plan:, user:, destination_id:)
    new(user:).update_destination(plan:, destination_id:)
  end

  def initialize(user:)
    @user = user
  end

  def start_exit(pass)
    target = pass.container
    raise Error, :container_not_in_yard unless target.current_yard_slot

    YardSlot.where(yard_block_id: target.current_yard_slot.yard_block_id).order(:id).lock.pluck(:id)
    return create_exit_order(pass, target) if GateMovementService.blocking_containers(target).empty?

    MovementPlan.transaction do
      plan = MovementPlan.find_or_create_by!(movement_pass: pass) do |item|
        item.container = target
        item.movement_type = "salida"
        item.origin_yard_slot = target.current_yard_slot
        item.created_by = @user
      end
      request = RehandlingRequest.find_or_create_by!(movement_pass: pass) do |item|
        item.container = target
        item.movement_plan = plan
        item.created_by = @user
      end
      request.update!(movement_plan: plan) unless request.movement_plan_id == plan.id
      advance(plan)
      request
    end
  end

  def advance(plan)
    MovementPlan.transaction do
      plan = MovementPlan.lock.find(plan.id)
      return unless plan.pendiente?
      return if plan.work_orders.where(status: "pendiente").exists?

      target = plan.container
      if GateMovementService.blocking_containers(target).empty?
        return unless plan.salida? || destination_valid?(plan)

        return create_target_order(plan)
      end

      schedule_next_rehandle(plan)
    end
  end

  def create_independent(container:, destination_id:)
    Container.transaction do
      container = Container.lock.find(container.id)
      raise Error, :container_not_in_yard unless container.current_yard_slot
      raise Error, :task_already_pending if container.work_orders.where(status: "pendiente").exists?
      raise Error, :request_already_pending if MovementPlan.where(container:, status: "pendiente").exists?

      destination = YardSlot.find_by(id: destination_id)
      raise Error, :destination_unavailable unless destination
      raise Error, :destination_unchanged if destination.id == container.current_yard_slot_id

      YardSlot.where(yard_block_id: [ container.current_yard_slot.yard_block_id, destination.yard_block_id ].uniq)
        .order(:id).lock.pluck(:id)
      validate_destination(container, destination)

      if GateMovementService.blocking_containers(container).empty?
        return WorkOrder.create!(
          container:,
          movement_type: "reacomodo",
          from_yard_slot: container.current_yard_slot,
          to_yard_slot: destination,
          created_by: @user
        )
      end

      plan = MovementPlan.create!(
        container:,
        movement_type: "reacomodo",
        origin_yard_slot: container.current_yard_slot,
        destination_yard_slot: destination,
        created_by: @user
      )
      advance(plan)
      plan
    end
  end

  def cancel(plan)
    MovementPlan.transaction do
      plan = MovementPlan.lock.find(plan.id)
      raise Error, :request_not_pending unless plan.pendiente?

      plan.work_orders.where(status: "pendiente").lock.each(&:cancelar!)
      plan.cancelar!
      plan.rehandling_request&.cancelar! if plan.rehandling_request&.pendiente?
      WorkScheduleService.close_if_finished(plan.work_schedule)
      plan
    end
  end

  def update_destination(plan:, destination_id:)
    MovementPlan.transaction do
      plan = MovementPlan.lock.find(plan.id)
      raise Error, :request_not_pending unless plan.pendiente?
      raise Error, :destination_already_scheduled if plan.pending_target_order

      destination = YardSlot.find_by(id: destination_id)
      raise Error, :destination_unavailable unless destination
      raise Error, :destination_unchanged if destination.id == plan.origin_yard_slot_id
      raise Error, :destination_not_desycon if plan.work_schedule_id && !destination.desycon?

      YardSlot.where(yard_block_id: [ plan.origin_yard_slot&.yard_block_id, destination.yard_block_id ].compact.uniq)
        .order(:id).lock.pluck(:id)
      validate_destination(plan.container, destination, except_movement_plan_id: plan.id)
      plan.update!(destination_yard_slot: destination)
    end
  end

  private

  def create_target_order(plan)
    attributes = {
      container: plan.container,
      movement_pass: plan.movement_pass,
      rehandling_request: plan.rehandling_request,
      movement_plan: plan,
      work_schedule_id: plan.work_schedule_id,
      movement_type: plan.movement_type,
      from_yard_slot: plan.container.current_yard_slot,
      to_yard_slot: plan.destination_yard_slot,
      created_by: @user
    }
    if plan.salida?
      order = WorkOrder.find_or_initialize_by(movement_pass: plan.movement_pass)
      order.assign_attributes(attributes)
      order.save! if order.new_record? || order.has_changes_to_save?
      return order
    end

    WorkOrder.create!(attributes)
  end

  def create_exit_order(pass, container)
    WorkOrder.find_or_create_by!(movement_pass: pass) do |order|
      order.container = container
      order.movement_type = "salida"
      order.from_yard_slot = container.current_yard_slot
      order.created_by = @user
    end
  end

  def schedule_next_rehandle(plan)
    candidate = GateMovementService.next_rehandle_candidate(plan.container)
    return unless candidate

    blocker = Container.lock.find(candidate.id)
    return if blocker.work_orders.where(status: "pendiente").exists?
    return if MovementPlan.where(container_id: blocker.id, status: "pendiente").where.not(id: plan.id).exists?

    create_rehandle_order(blocker, plan)
  end

  def create_rehandle_order(container, plan)
    GateMovementService.available_slots(container).each do |destination|
      next if blocks_target_column?(container, destination, plan.container)

      lock_yard_blocks(destination.yard_block_id)
      next unless GateMovementService.available_slots(container).include?(destination)
      next if blocks_target_column?(container, destination, plan.container)

      return WorkOrder.create!(
        container:,
        movement_plan: plan,
        rehandling_request: plan.rehandling_request,
        movement_type: "reacomodo",
        from_yard_slot: container.current_yard_slot,
        to_yard_slot: destination,
        created_by: @user
      )
    end
  end

  def destination_valid?(plan)
    lock_yard_blocks(plan.destination_yard_slot&.yard_block_id)
    validate_destination(
      plan.container,
      plan.destination_yard_slot,
      except_movement_plan_id: plan.id
    )
    true
  rescue Error
    false
  end

  def lock_yard_blocks(*block_ids)
    YardSlot.where(yard_block_id: block_ids.compact.uniq).order(:id).lock.pluck(:id)
  end

  def validate_destination(container, destination, except_movement_plan_id: nil)
    footprint = GateMovementService.footprint_for(container, destination)
    raise Error, :destination_unavailable unless footprint
    raise Error, :destination_not_owner unless GateMovementService.allowed_destination?(container, destination)

    occupied = GateMovementService.occupied_positions(destination.yard_block_id)
    raise Error, :destination_occupied if footprint.any? { |position| occupied.include?(position) }
    reserved = GateMovementService.reserved_positions(
      destination.yard_block_id,
      except_movement_plan_id:
    )
    raise Error, :destination_occupied if footprint.any? { |position| reserved.include?(position) }
    raise Error, :destination_unsupported unless GateMovementService.supported_footprint?(footprint, occupied)
  end

  def blocks_target_column?(container, destination, target)
    target_slot = target.current_yard_slot
    target_columns = GateMovementService.occupied_footprint(target)
      .map { |block_id, bay, row, _level| [ block_id, bay, row ] }
    GateMovementService.footprint_for(container, destination).any? do |block_id, bay, row, level|
      level > target_slot.level && target_columns.include?([ block_id, bay, row ])
    end
  end
end

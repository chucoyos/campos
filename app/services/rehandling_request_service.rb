class RehandlingRequestService
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

  def self.advance(request)
    new(user: request.created_by).advance(request)
  end

  def self.advance_pending
    RehandlingRequest.where(status: "pendiente").find_each do |request|
      new(user: request.created_by).advance(request)
    end
  end

  def self.create_independent(container:, user:, destination_id:)
    new(user:).create_independent(container:, destination_id:)
  end

  def self.cancel(request:, user:)
    new(user:).cancel(request)
  end

  def initialize(user:)
    @user = user
  end

  def start_exit(pass)
    target = pass.container
    raise Error, :container_not_in_yard unless target.current_yard_slot

    YardSlot.where(yard_block_id: target.current_yard_slot.yard_block_id).order(:id).lock.pluck(:id)
    if GateMovementService.blocking_containers(target).empty?
      return create_exit_order(pass, target)
    end

    request = RehandlingRequest.find_or_create_by!(movement_pass: pass) do |item|
      item.container = target
      item.created_by = @user
    end
    schedule_next_rehandle(request)
    request
  end

  def advance(request)
    return unless request.pendiente?

    target = request.container
    if GateMovementService.blocking_containers(target).empty?
      create_exit_order(request.movement_pass, target, request:)
    else
      schedule_next_rehandle(request)
    end
  end

  def create_independent(container:, destination_id:)
    Container.transaction do
      container = Container.lock.find(container.id)
      raise Error, :container_not_in_yard unless container.current_yard_slot
      raise Error, :task_already_pending if container.work_orders.where(status: "pendiente").exists?
      raise Error, :request_already_pending if container.rehandling_requests.where(status: "pendiente").exists?
      raise Error, :container_supports_other if GateMovementService.supporting_other?(container)

      destination = YardSlot.find_by(id: destination_id)
      raise Error, :destination_unavailable unless destination
      raise Error, :destination_unchanged if destination.id == container.current_yard_slot_id

      YardSlot.where(yard_block_id: [ container.current_yard_slot.yard_block_id, destination.yard_block_id ].uniq)
        .order(:id).lock.pluck(:id)
      raise Error, :container_supports_other if GateMovementService.supporting_other?(container)
      validate_destination(container, destination)

      WorkOrder.create!(
        container:,
        movement_type: "reacomodo",
        from_yard_slot: container.current_yard_slot,
        to_yard_slot: destination,
        created_by: @user
      )
    end
  end

  def cancel(request)
    RehandlingRequest.transaction do
      request = RehandlingRequest.lock.find(request.id)
      raise Error, :request_not_pending unless request.pendiente?

      request.work_orders.where(status: "pendiente").lock.each(&:cancelar!)
      request.cancelar!
      request
    end
  end

  def schedule_next_rehandle(request)
    return if request.work_orders.pendiente.exists?

    blocker = GateMovementService.next_rehandle_candidate(request.container)
    return unless blocker
    return if blocker.work_orders.where(status: "pendiente").exists?

    create_rehandle_order(blocker, request)
  end

  private

  def create_exit_order(pass, container, request: nil)
    WorkOrder.find_or_create_by!(movement_pass: pass) do |order|
      order.container = container
      order.movement_type = "salida"
      order.from_yard_slot = container.current_yard_slot
      order.created_by = @user
      order.rehandling_request = request
    end
  end

  def create_rehandle_order(container, request)
    destination = GateMovementService.available_slots(container).find do |slot|
      !blocks_exit_target?(container, slot, request.container)
    end
    return unless destination

    WorkOrder.create!(
      container: container,
      rehandling_request: request,
      movement_type: "reacomodo",
      from_yard_slot: container.current_yard_slot,
      to_yard_slot: destination,
      created_by: @user
    )
  end

  def validate_destination(container, destination)
    footprint = GateMovementService.footprint_for(container, destination)
    raise Error, :destination_unavailable unless footprint

    occupied = GateMovementService.occupied_positions(destination.yard_block_id)
    raise Error, :destination_occupied if footprint.any? { |position| occupied.include?(position) }
    reserved = GateMovementService.reserved_positions(destination.yard_block_id)
    raise Error, :destination_occupied if footprint.any? { |position| reserved.include?(position) }
    raise Error, :destination_unsupported unless GateMovementService.supported_footprint?(footprint, occupied)
  end

  def blocks_exit_target?(container, destination, target)
    target_slot = target.current_yard_slot
    target_columns = GateMovementService.occupied_footprint(target).map { |block_id, bay, row, _level| [ block_id, bay, row ] }
    GateMovementService.footprint_for(container, destination).any? do |block_id, bay, row, level|
      level > target_slot.level && target_columns.include?([ block_id, bay, row ])
    end
  end
end

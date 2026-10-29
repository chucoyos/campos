class WorkScheduleService
  class Error < StandardError
    def initialize(key, container: nil)
      super(I18n.t("work_schedules.errors.#{key}", container: container&.number))
    end
  end

  def self.create(container_ids:, scheduled_for:, user:, master_bl: nil, notes: nil)
    new(user).create(container_ids:, scheduled_for:, master_bl:, notes:)
  end

  def self.cancel(schedule:, user:)
    new(user).cancel(schedule)
  end

  # Cierra la programación cuando ya no quedan tareas ni planes pendientes.
  def self.close_if_finished(schedule)
    return unless schedule

    WorkSchedule.transaction do
      schedule = WorkSchedule.lock.find(schedule.id)
      schedule.completar! if schedule.activa? && schedule.finished?
    end
  end

  def initialize(user)
    @user = user
  end

  def create(container_ids:, scheduled_for:, master_bl:, notes:)
    ids = Array(container_ids).compact_blank.map(&:to_i).uniq
    raise Error, :no_containers if ids.empty?

    WorkSchedule.transaction do
      schedule = WorkSchedule.create!(master_bl:, scheduled_for:, notes: notes.presence, created_by: @user)
      lock_yard
      containers = Container.where(id: ids).includes(:current_yard_slot).order(:id).lock.to_a
      raise Error, :invalid_containers if containers.size != ids.size

      # Los contenedores de niveles altos se programan primero para que no se vean bloqueados por otros de la lista.
      containers.sort_by { |container| -container.current_yard_slot&.level.to_i }.each do |container|
        schedule_container(schedule, container)
      end
      schedule
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error, :invalid_schedule if error.record.is_a?(WorkSchedule)

    raise
  end

  def cancel(schedule)
    WorkSchedule.transaction do
      schedule = WorkSchedule.lock.find(schedule.id)
      raise Error, :not_active unless schedule.activa?

      schedule.pending_movement_plans.lock.each { |plan| MovementPlanService.cancel(plan:, user: @user) }
      schedule.pending_work_orders.lock.each(&:cancelar!)
      schedule.cancelar!
      schedule
    end
  end

  private

  def lock_yard
    YardSlot.order(:id).lock.pluck(:id)
  end

  def schedule_container(schedule, container)
    origin = container.current_yard_slot
    raise Error.new(:not_in_yard, container:) unless origin
    raise Error.new(:already_in_desycon, container:) if origin.desycon?
    raise Error.new(:task_pending, container:) if container.work_orders.where(status: "pendiente").exists? ||
      container.movement_plans.where(status: "pendiente").exists?

    destination = GateMovementService.available_slots(container).find(&:desycon?)
    raise Error.new(:no_desycon_space, container:) unless destination

    if GateMovementService.blocking_containers(container).empty?
      WorkOrder.create!(
        container:, movement_type: "reacomodo", from_yard_slot: origin, to_yard_slot: destination,
        work_schedule: schedule, created_by: @user
      )
    else
      plan = MovementPlan.create!(
        container:, movement_type: "reacomodo", origin_yard_slot: origin, destination_yard_slot: destination,
        work_schedule: schedule, created_by: @user
      )
      MovementPlanService.new(user: @user).advance(plan)
    end
  end
end

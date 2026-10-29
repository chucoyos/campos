class WorkSchedulesController < ApplicationController
  Row = Struct.new(:container, :origin, :destination, :status, :blocked, keyword_init: true)

  def index
    authorize WorkSchedule
    @pagy, @schedules = paginate(policy_scope(WorkSchedule).includes(:master_bl).order(scheduled_for: :desc, id: :desc))
    @progress = @schedules.to_h { |schedule| [ schedule.id, progress_for(schedule) ] }
  end

  def show
    @schedule = policy_scope(WorkSchedule).includes(:master_bl).find(params[:id])
    authorize @schedule
    @rows = rows_for(@schedule)
  end

  def new
    authorize WorkSchedule, :create?
    @schedule = WorkSchedule.new(scheduled_for: Date.current)
    @master_bls = MasterBl.where(id: Container.where.not(current_yard_slot_id: nil).select(:master_bl_id)).order(:number)
    @master_bl = @master_bls.find_by(id: params[:master_bl_id])
    load_candidates if @master_bl
  end

  def create
    authorize WorkSchedule
    master_bl = MasterBl.find(params[:master_bl_id])
    schedule = WorkScheduleService.create(
      master_bl:, container_ids: params[:container_ids], scheduled_for: params[:scheduled_for],
      notes: params[:notes], user: current_user
    )
    redirect_to schedule, notice: t("flash.work_schedules.create")
  rescue WorkScheduleService::Error => error
    redirect_to new_work_schedule_path(master_bl_id: params[:master_bl_id]), alert: error.message
  end

  def cancel
    schedule = policy_scope(WorkSchedule).find(params[:id])
    authorize schedule
    WorkScheduleService.cancel(schedule:, user: current_user)
    redirect_to schedule, notice: t("flash.work_schedules.cancel")
  rescue WorkScheduleService::Error => error
    redirect_to schedule, alert: error.message
  end

  private

  def load_candidates
    busy = WorkOrder.where(status: "pendiente").pluck(:container_id) +
      MovementPlan.where(status: "pendiente").pluck(:container_id)
    containers = @master_bl.containers.where.not(current_yard_slot_id: nil)
      .includes(current_yard_slot: :yard_block).order(:number).reject { |container| container.current_yard_slot.desycon? }
    @candidates = containers.map { |container| [ container, busy.include?(container.id) ] }
  end

  def entries(schedule)
    orders = schedule.work_orders.where(movement_plan_id: nil).includes(:container, :from_yard_slot, :to_yard_slot)
    plans = schedule.movement_plans.includes(:container, :origin_yard_slot, :destination_yard_slot)
    [ orders, plans ]
  end

  def progress_for(schedule)
    orders, plans = [ schedule.work_orders.where(movement_plan_id: nil), schedule.movement_plans ]
    statuses = orders.pluck(:status) + plans.pluck(:status)
    { total: statuses.size, done: statuses.count("completada") }
  end

  def rows_for(schedule)
    orders, plans = entries(schedule)
    orders.map { |order| Row.new(container: order.container, origin: order.from_yard_slot, destination: order.to_yard_slot, status: order.status, blocked: false) } +
      plans.map { |plan| Row.new(container: plan.container, origin: plan.origin_yard_slot, destination: plan.destination_yard_slot, status: plan.status, blocked: true) }
  end
end

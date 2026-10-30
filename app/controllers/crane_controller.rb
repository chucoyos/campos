class CraneController < ApplicationController
  def index
    authorize WorkOrder
    @queue = params[:queue] == "scheduled" ? "scheduled" : "normal"
    orders_scope = policy_scope(WorkOrder).where(status: "pendiente")
    plans_scope = policy_scope(MovementPlan).where(status: "pendiente")
    count_queue_sizes(orders_scope, plans_scope)

    @plans = queue_filter(plans_scope).includes(:container, :destination_yard_slot, { work_orders: %i[container from_yard_slot to_yard_slot] }, movement_pass: :vehicles)
      .order(:created_at)
    @work_orders = queue_filter(orders_scope).where(movement_plan_id: nil)
      .or(orders_scope.where(movement_plan_id: @plans.map(&:id)))
      .order(:created_at)
      .includes({ container: :master_bl }, :from_yard_slot, :to_yard_slot, :rehandling_request, movement_pass: :vehicles)
    @standalone_work_orders = @work_orders.reject { |order| order.movement_plan_id || order.rehandling_request_id }
    @pending_orders_by_plan = @work_orders.filter_map do |order|
      [ order.movement_plan_id, order ] if order.movement_plan_id
    end.to_h
    @destination_options = @work_orders.select(&:reacomodo?).to_h do |order|
      [ order.id, destination_slots(order.container, order.work_schedule_id, except_work_order_id: order.id, except_movement_plan_id: order.movement_plan_id) ]
    end
    @plan_destination_options = @plans.select(&:reacomodo?).to_h do |plan|
      [ plan.id, destination_slots(plan.container, plan.work_schedule_id, except_movement_plan_id: plan.id) ]
    end
    load_schedules if @queue == "scheduled"
  end

  def complete
    work_order = policy_scope(WorkOrder).find(params[:id])
    authorize work_order
    CraneTaskService.complete(work_order:, user: current_user, yard_slot_id: params[:yard_slot_id])
    redirect_to crane_return_path, notice: t("flash.crane.completed")
  rescue CraneTaskService::Error => error
    redirect_to crane_return_path, alert: error.message
  end

  def search_rehandles
    authorize WorkOrder, :index?
    query = params[:q].to_s.strip
    @containers = if query.length >= 3
      pending_ids = WorkOrder.where(status: "pendiente").select(:container_id)
      active_plan_ids = MovementPlan.where(status: "pendiente").select(:container_id)
      Container.joins(:current_yard_slot).where.not(id: pending_ids).where.not(id: active_plan_ids)
        .where("containers.number ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
        .includes(:current_yard_slot).order(:number).limit(50)
        .first(10)
    else
      Container.none
    end
    render partial: "crane/rehandle_search_results", locals: { containers: @containers, query: }
  end

  def new_rehandle
    authorize WorkOrder, :create?
    @container = rehandle_candidate
    @destinations = GateMovementService.available_slots(@container)
    @suggested_destination = @destinations.first
  rescue ActiveRecord::RecordNotFound
    redirect_to crane_path, alert: t("crane.errors.container_not_eligible")
  end

  def create_rehandle
    authorize WorkOrder, :create?
    container = rehandle_candidate
    result = MovementPlanService.create_independent(
      container:, user: current_user, destination_id: params[:yard_slot_id]
    )
    notice_key = result.is_a?(MovementPlan) && !result.work_orders.where(status: "pendiente").exists? ?
      "flash.crane.rehandle_plan_waiting" : "flash.crane.rehandle_created"
    redirect_to crane_path, notice: t(notice_key)
  rescue ActiveRecord::RecordNotFound
    redirect_to crane_path, alert: t("crane.errors.container_not_eligible")
  rescue MovementPlanService::Error => error
    redirect_to crane_path, alert: error.message
  end

  def cancel_request
    request = policy_scope(RehandlingRequest).find(params[:id])
    plan = policy_scope(MovementPlan).find(request.movement_plan_id)
    authorize plan, :cancel?
    MovementPlanService.cancel(plan:, user: current_user)
    redirect_to crane_return_path, notice: t("flash.crane.request_canceled")
  rescue MovementPlanService::Error => error
    redirect_to crane_return_path, alert: error.message
  end

  def cancel_plan
    plan = policy_scope(MovementPlan).find(params[:id])
    authorize plan, :cancel?
    MovementPlanService.cancel(plan:, user: current_user)
    redirect_to crane_return_path, notice: t("flash.crane.request_canceled")
  rescue MovementPlanService::Error => error
    redirect_to crane_return_path, alert: error.message
  end

  def update_plan_destination
    plan = policy_scope(MovementPlan).find(params[:id])
    authorize plan, :update_destination?
    MovementPlanService.update_destination(plan:, user: current_user, destination_id: params[:yard_slot_id])
    redirect_to crane_return_path, notice: t("flash.crane.destination_updated")
  rescue MovementPlanService::Error => error
    redirect_to crane_return_path, alert: error.message
  end

  def retry_plan
    plan = policy_scope(MovementPlan).find(params[:id])
    authorize plan, :retry?
    task = MovementPlanService.advance(plan)
    notice_key = task ? "flash.crane.plan_retried" : "flash.crane.plan_waiting"
    redirect_to crane_return_path, notice: t(notice_key)
  rescue MovementPlanService::Error => error
    redirect_to crane_return_path, alert: error.message
  end

  def cancel
    work_order = policy_scope(WorkOrder).find(params[:id])
    authorize work_order
    work_order.cancelar!
    redirect_to crane_return_path, notice: t("flash.crane.canceled")
  end

  private

  def crane_return_path = crane_path(queue: params[:queue].presence_in(%w[scheduled]))

  def scheduled_queue? = @queue == "scheduled"

  def queue_filter(scope)
    scheduled_queue? ? scope.where.not(work_schedule_id: nil) : scope.where(work_schedule_id: nil)
  end

  def count_queue_sizes(orders_scope, plans_scope)
    scheduled = orders_scope.where.not(work_schedule_id: nil).where(movement_plan_id: nil).count +
      plans_scope.where.not(work_schedule_id: nil).count
    normal = orders_scope.where(work_schedule_id: nil, movement_plan_id: nil, rehandling_request_id: nil).count +
      plans_scope.where(work_schedule_id: nil).count
    @queue_counts = { "normal" => normal, "scheduled" => scheduled }
  end

  # Las tareas de programación solo pueden terminar en DESYCON.
  def destination_slots(container, work_schedule_id, **except)
    GateMovementService.available_slots(container, desycon: work_schedule_id.present?, **except)
  end

  def load_schedules
    ids = (@standalone_work_orders.map(&:work_schedule_id) + @plans.map(&:work_schedule_id)).compact.uniq
    @schedules = WorkSchedule.where(id: ids).includes(:master_bl).order(:scheduled_for, :id)
  end

  def rehandle_candidate
    pending_ids = WorkOrder.where(status: "pendiente").select(:container_id)
    plan_ids = MovementPlan.where(status: "pendiente").select(:container_id)
    container = Container.joins(:current_yard_slot).where.not(id: pending_ids).where.not(id: plan_ids)
      .find(params[:container_id])
    container
  end
end

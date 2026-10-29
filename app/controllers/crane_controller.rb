class CraneController < ApplicationController
  def index
    authorize WorkOrder
    @work_orders = policy_scope(WorkOrder).where(status: "pendiente").order(:created_at)
      .includes({ container: :master_bl }, :from_yard_slot, :to_yard_slot, :rehandling_request, movement_pass: :vehicles)
    @plans = policy_scope(MovementPlan).where(status: "pendiente")
      .includes(:container, :destination_yard_slot, { work_orders: %i[container from_yard_slot to_yard_slot] }, movement_pass: :vehicles)
      .order(:created_at)
    @standalone_work_orders = @work_orders.reject { |order| order.movement_plan_id || order.rehandling_request_id }
    @pending_orders_by_plan = @work_orders.filter_map do |order|
      [ order.movement_plan_id, order ] if order.movement_plan_id
    end.to_h
    @destination_options = @work_orders.select(&:reacomodo?).to_h do |order|
      [ order.id, GateMovementService.available_slots(
        order.container,
        except_work_order_id: order.id,
        except_movement_plan_id: order.movement_plan_id
      ) ]
    end
    @plan_destination_options = @plans.select(&:reacomodo?).to_h do |plan|
      [ plan.id, GateMovementService.available_slots(plan.container, except_movement_plan_id: plan.id) ]
    end
  end

  def complete
    work_order = policy_scope(WorkOrder).find(params[:id])
    authorize work_order
    CraneTaskService.complete(work_order:, user: current_user, yard_slot_id: params[:yard_slot_id])
    redirect_to crane_path, notice: t("flash.crane.completed")
  rescue CraneTaskService::Error => error
    redirect_to crane_path, alert: error.message
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
    redirect_to crane_path, notice: t("flash.crane.request_canceled")
  rescue MovementPlanService::Error => error
    redirect_to crane_path, alert: error.message
  end

  def cancel_plan
    plan = policy_scope(MovementPlan).find(params[:id])
    authorize plan, :cancel?
    MovementPlanService.cancel(plan:, user: current_user)
    redirect_to crane_path, notice: t("flash.crane.request_canceled")
  rescue MovementPlanService::Error => error
    redirect_to crane_path, alert: error.message
  end

  def update_plan_destination
    plan = policy_scope(MovementPlan).find(params[:id])
    authorize plan, :update_destination?
    MovementPlanService.update_destination(plan:, user: current_user, destination_id: params[:yard_slot_id])
    redirect_to crane_path, notice: t("flash.crane.destination_updated")
  rescue MovementPlanService::Error => error
    redirect_to crane_path, alert: error.message
  end

  def retry_plan
    plan = policy_scope(MovementPlan).find(params[:id])
    authorize plan, :retry?
    task = MovementPlanService.advance(plan)
    notice_key = task ? "flash.crane.plan_retried" : "flash.crane.plan_waiting"
    redirect_to crane_path, notice: t(notice_key)
  rescue MovementPlanService::Error => error
    redirect_to crane_path, alert: error.message
  rescue MovementPlanService::Error => error
    redirect_to crane_path, alert: error.message
  end

  def cancel
    work_order = policy_scope(WorkOrder).find(params[:id])
    authorize work_order
    work_order.cancelar!
    redirect_to crane_path, notice: t("flash.crane.canceled")
  end

  private

  def rehandle_candidate
    pending_ids = WorkOrder.where(status: "pendiente").select(:container_id)
    plan_ids = MovementPlan.where(status: "pendiente").select(:container_id)
    container = Container.joins(:current_yard_slot).where.not(id: pending_ids).where.not(id: plan_ids)
      .find(params[:container_id])
    container
  end
end

class CraneController < ApplicationController
  def index
    authorize WorkOrder
    @work_orders = policy_scope(WorkOrder).where(status: "pendiente").order(:created_at)
      .includes({ container: :master_bl }, :from_yard_slot, :to_yard_slot, :rehandling_request, movement_pass: :vehicles)
    @requests = policy_scope(RehandlingRequest).where(status: "pendiente")
      .includes(:container, { work_orders: %i[container from_yard_slot to_yard_slot] }, movement_pass: :vehicles)
      .order(:created_at)
    @standalone_work_orders = @work_orders.reject(&:rehandling_request_id)
    @pending_orders_by_request = @work_orders.filter_map do |order|
      [ order.rehandling_request_id, order ] if order.rehandling_request_id
    end.to_h
    @destination_options = @work_orders.select(&:reacomodo?).to_h do |order|
      [ order.id, GateMovementService.available_slots(order.container, except_work_order_id: order.id) ]
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
      active_request_ids = RehandlingRequest.where(status: "pendiente").select(:container_id)
      Container.joins(:current_yard_slot).where.not(id: pending_ids).where.not(id: active_request_ids)
        .where("containers.number ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
        .includes(:current_yard_slot).order(:number).limit(50)
        .reject { |container| GateMovementService.supporting_other?(container) }.first(10)
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
    RehandlingRequestService.create_independent(
      container:, user: current_user, destination_id: params[:yard_slot_id]
    )
    redirect_to crane_path, notice: t("flash.crane.rehandle_created")
  rescue ActiveRecord::RecordNotFound
    redirect_to crane_path, alert: t("crane.errors.container_not_eligible")
  rescue RehandlingRequestService::Error => error
    redirect_to crane_path, alert: error.message
  end

  def cancel_request
    request = policy_scope(RehandlingRequest).find(params[:id])
    authorize request, :cancel?
    RehandlingRequestService.cancel(request:, user: current_user)
    redirect_to crane_path, notice: t("flash.crane.request_canceled")
  rescue RehandlingRequestService::Error => error
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
    request_ids = RehandlingRequest.where(status: "pendiente").select(:container_id)
    container = Container.joins(:current_yard_slot).where.not(id: pending_ids).where.not(id: request_ids)
      .find(params[:container_id])
    raise ActiveRecord::RecordNotFound if GateMovementService.supporting_other?(container)

    container
  end
end

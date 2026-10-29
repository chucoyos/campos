class CraneController < ApplicationController
  def index
    authorize WorkOrder
    @work_orders = policy_scope(WorkOrder).where(status: "pendiente").order(:created_at)
      .includes(:container, :to_yard_slot, movement_pass: :vehicles)
  end

  def complete
    work_order = policy_scope(WorkOrder).find(params[:id])
    authorize work_order
    CraneTaskService.complete(work_order:, user: current_user)
    redirect_to crane_path, notice: t("flash.crane.completed")
  rescue CraneTaskService::Error => error
    redirect_to crane_path, alert: error.message
  end

  def cancel
    work_order = policy_scope(WorkOrder).find(params[:id])
    authorize work_order
    work_order.cancelar!
    redirect_to crane_path, notice: t("flash.crane.canceled")
  end
end

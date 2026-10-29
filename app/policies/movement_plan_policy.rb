class MovementPlanPolicy < ApplicationPolicy
  def index? = operator?
  def show? = operator?
  def cancel? = user&.admin? && record.pendiente?
  def update_destination? = operator? && record.pendiente? && record.reacomodo? && record.pending_target_order.nil?
  def retry? = operator? && record.pendiente?

  class Scope < Scope
    def resolve
      user&.admin? || user&.grua? ? scope.all : scope.none
    end
  end

  private

  def operator? = user&.admin? || user&.grua?
end

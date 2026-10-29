class WorkOrderPolicy < ApplicationPolicy
  def index? = operator?
  def create? = operator?
  def complete? = operator? && record.pendiente?
  def cancel? = user&.admin? && record.pendiente? && record.rehandling_request.nil?

  class Scope < Scope
    def resolve
      user&.admin? || user&.grua? ? scope.all : scope.none
    end
  end

  private

  def operator? = user&.admin? || user&.grua?
end

class ContainerAssignmentPolicy < ApplicationPolicy
  def index? = user&.admin? || user&.seguridad? || user&.carrier_member?
  def show? = index?
  def create? = user&.admin?
  def cancel? = user&.admin?

  class Scope < Scope
    def resolve
      if user&.admin? || user&.seguridad?
        scope.all
      elsif user&.carrier_member?
        scope.where(carrier_id: user.carrier_id)
      else
        scope.none
      end
    end
  end
end

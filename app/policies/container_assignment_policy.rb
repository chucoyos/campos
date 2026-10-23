class ContainerAssignmentPolicy < ApplicationPolicy
  def index? = user&.admin? || user&.seguridad? || user&.carrier_member?
  def show? = index?
  def create? = user&.admin?
  def cancel? = user&.admin?
  # El transportista no ve el cliente ni la ubicación preasignada en el patio.
  def view_internal_details? = user&.admin? || user&.seguridad?

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

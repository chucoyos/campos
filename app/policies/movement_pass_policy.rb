class MovementPassPolicy < ApplicationPolicy
  def index? = user.present? && (user.admin? || user.seguridad? || user.carrier_member? || user.client_member?)
  def gate? = user&.admin? || user&.seguridad?

  def show?
    return false unless index?

    user.admin? || user.seguridad? || owned_by_user?
  end

  def create?
    return false unless user
    return user.admin? || user.carrier_member? || user.client_member? if record.is_a?(Class)

    manage?
  end

  def new? = create?
  def download? = show?
  def cancel? = record.vigente? && !record.entered_at? && manage?

  # El cliente solo se muestra al personal interno y al propio cliente, no al transportista.
  def view_client?
    user.admin? || user.seguridad? || (user.client_member? && record.client_id == user.client_id)
  end

  private

  # Admin gestiona todo; el transporte, las asignaciones de su carrier; el cliente, sus contenedores de resguardo.
  def manage?
    return true if user.admin?

    assignment = record.container_assignment
    if assignment
      user.carrier_member? && assignment.carrier_id == user.carrier_id
    else
      user.client_member? && record.container&.client_id == user.client_id && !record.container.with_master_bl?
    end
  end

  def owned_by_user?
    record.requested_by_id == user.id ||
      (user.carrier_member? && record.carrier_id == user.carrier_id) ||
      (user.client_member? && record.client_id == user.client_id)
  end

  class Scope < Scope
    def resolve
      return scope.none unless user
      return scope.all if user.admin? || user.seguridad?

      relation = scope.where(requested_by_id: user.id)
      relation = relation.or(scope.where(carrier_id: user.carrier_id)) if user.carrier_member?
      relation = relation.or(scope.where(client_id: user.client_id)) if user.client_member?
      relation
    end
  end
end

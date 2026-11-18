class CargoDispatchTripPolicy < ApplicationPolicy
  def index? = user&.admin? || user&.client_member? || user&.carrier_member?

  def show?
    return false unless user
    return true if user.admin?

    customer? || carrier?
  end

  def create?
    return false unless user
    return true if user.admin?
    return false unless record.is_a?(CargoDispatchTrip)

    customer? && record.origin_type == "general" && record.carrier_id.nil?
  end

  def reserve? = user&.admin?
  def assign_carrier? = user&.admin?
  def prepare? = user&.admin?
  def confirm_loading? = user&.admin?
  def cancel? = user&.admin?
  def report? = user&.admin? || user&.montacargas?
  def issue_pass? = user&.admin? || (record.transport_mode == "customer" ? customer? : carrier?)
  def tally? = show? && record.exit_evidence_enabled? && (record.loaded? || record.completed?)
  def exit_photos? = show? && record.exit_evidence_enabled? && record.completed?
  def manage_exit_photos? = user&.admin? && record.exit_evidence_enabled? && record.completed?

  class Scope < Scope
    def resolve
      return scope.all if user&.admin?
      return scope.none unless user

      request_ids = CargoDispatchRequest.where(client_id: user.client_id).select(:id) if user.client_member?
      client_scope = scope.where(cargo_dispatch_request_id: request_ids) if request_ids
      carrier_scope = scope.where(transport_mode: "assigned", carrier_id: user.carrier_id) if user.carrier_member?
      return client_scope.or(carrier_scope) if client_scope && carrier_scope

      client_scope || carrier_scope || scope.none
    end
  end

  private

  def customer? = user&.client_member? && record.cargo_dispatch_request.client_id == user.client_id
  def carrier? = user&.carrier_member? && record.transport_mode == "assigned" && record.carrier_id == user.carrier_id
end

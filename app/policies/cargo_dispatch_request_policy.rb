class CargoDispatchRequestPolicy < ApplicationPolicy
  def index? = user&.admin? || user&.client_member?
  def show? = user&.admin? || owner?
  def create? = user&.admin? || user&.client_member?
  def add_instruction? = show? && (record.pending? || record.in_progress?)
  def remove_instruction? = add_instruction?

  class Scope < Scope
    def resolve
      return scope.all if user&.admin?
      return scope.where(client_id: user.client_id) if user&.client_member?

      scope.none
    end
  end

  private

  def owner? = user&.client_member? && record.is_a?(CargoDispatchRequest) && record.client_id == user.client_id
end

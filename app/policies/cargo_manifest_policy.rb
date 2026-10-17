class CargoManifestPolicy < ApplicationPolicy
  def index? = manager? || client_user?
  def show? = manager? || owner?
  def create? = manager? || (owner? && client_may_manage?)
  def update? = record.draft? && (manager? || (owner? && client_may_manage?))
  def destroy? = record.draft? && (user&.admin? || (owner? && client_may_manage?))
  def confirm? = record.draft? && (manager? || (owner? && client_may_manage?))
  def reopen? = record.confirmed? && user&.admin?
  def history? = user&.admin?
  def template? = show?
  def import? = update?

  class Scope < Scope
    def resolve
      if user&.admin? || user&.seguridad?
        scope.all
      elsif user&.cliente? && user.client_id
        scope.for_client(user.client_id)
      else
        scope.none
      end
    end
  end

  private

  def manager? = user&.admin? || user&.seguridad?
  def client_user? = user&.cliente? && user.client_id.present?
  def owner? = client_user? && record.is_a?(CargoManifest) && record.client_id == user.client_id

  def client_may_manage?
    record.container.nil? || record.container.master_bl&.open_for_client?
  end
end

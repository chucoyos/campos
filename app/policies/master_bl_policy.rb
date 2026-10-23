class MasterBlPolicy < ApplicationPolicy
  def index? = admin? || client_user?
  def show? = admin? || owner?
  def create? = admin? || (client_user? && (!record.is_a?(MasterBl) || owner?))
  def update? = admin? || (owner? && record.open_for_client?)
  def destroy? = admin?
  def template? = show?
  def document? = show?
  def import? = update?
  def upload_document? = update?
  def remove_document? = update?

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user&.client_member?
        scope.where(client_id: user.client_id)
      else
        scope.none
      end
    end
  end

  private

  def admin? = user&.admin?
  def client_user? = user&.client_member?
  def owner? = client_user? && record.is_a?(MasterBl) && record.client_id == user.client_id
end

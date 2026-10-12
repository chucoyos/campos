class ContainerPolicy < ApplicationPolicy
  def index? = user&.admin?
  def show? = user&.admin?
  def create? = user&.admin?
  def update? = user&.admin?
  def destroy? = user&.admin?
  def transition? = user&.admin?
  def photos? = user&.admin?
  def upload_photos? = user&.admin?
  def remove_photo? = user&.admin?

  class Scope < Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end
end

class ContainerPolicy < ApplicationPolicy
  def index? = manager?
  def show? = manager?
  def create? = manager?
  def update? = manager?
  def destroy? = manager?
  def photos? = manager?
  def upload_photos? = manager?
  def remove_photo? = manager?
  def remove_photos? = manager?
  def zip_photos? = manager?
  # Los cambios de estado del flujo con MBL son solo del administrador.
  def transition? = user&.admin?

  class Scope < Scope
    def resolve
      user&.admin? || user&.seguridad? ? scope.all : scope.none
    end
  end

  private

  def manager? = user&.admin? || user&.seguridad?
end

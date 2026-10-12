class ContainerPolicy < ApplicationPolicy
  def index? = manager? || client_user?
  def show? = manager? || client_owner?
  def create? = manager? || client_can_modify?
  def update? = manager? || client_can_modify?
  def destroy? = manager?
  def photos? = manager? || client_owner?
  def upload_photos? = manager?
  def remove_photo? = manager?
  def remove_photos? = manager?
  def zip_photos? = manager? || client_owner?
  # Los cambios de estado del flujo con MBL son solo del administrador.
  def transition? = user&.admin?

  class Scope < Scope
    def resolve
      if user&.admin? || user&.seguridad?
        scope.all
      elsif user&.cliente? && user.client_id
        scope.joins(:master_bl).where(master_bls: { client_id: user.client_id })
      else
        scope.none
      end
    end
  end

  private

  def manager? = user&.admin? || user&.seguridad?
  def client_user? = user&.cliente? && user.client_id.present?

  def client_owner?
    client_user? && record.is_a?(Container) && record.master_bl&.client_id == user.client_id
  end

  # El cliente solo crea y corrige contenedores de su propio MBL mientras siga abierto.
  def client_can_modify?
    client_owner? && record.master_bl.open_for_client?
  end
end

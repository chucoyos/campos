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
      elsif user&.client_member?
        scope.left_joins(:master_bl).where(master_bls: { client_id: user.client_id }).or(scope.left_joins(:master_bl).where(client_id: user.client_id))
      else
        scope.none
      end
    end
  end

  private

  def manager? = user&.admin? || user&.seguridad?
  def client_user? = user&.client_member?

  def client_owner?
    client_user? && record.is_a?(Container) && record.owner_client_id == user.client_id
  end

  # El cliente solo crea y corrige contenedores de su propio MBL mientras siga abierto.
  def client_can_modify?
    client_owner? && (record.master_bl.nil? || record.master_bl.open_for_client?)
  end
end

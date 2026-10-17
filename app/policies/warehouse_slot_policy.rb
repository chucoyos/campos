class WarehouseSlotPolicy < ApplicationPolicy
  def index? = operator?
  def show? = operator?
  def store? = user&.admin? || user&.montacargas?
  def labels? = operator?

  private

  def operator? = user&.admin? || user&.seguridad? || user&.montacargas?
end

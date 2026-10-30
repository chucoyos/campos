# Política sin modelo para la consola de montacargas.
class ForkliftPolicy < ApplicationPolicy
  def index? = operator?
  def pick? = operator?
  def store? = operator?

  private

  def operator? = user&.admin? || user&.montacargas?
end

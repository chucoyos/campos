class DeconsolidationPolicy < ApplicationPolicy
  def index? = operator?
  def show? = operator?
  def create? = operator?
  def advance? = operator?
  def labels? = operator?

  class Scope < Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end

  private

  # Único punto que decide quién opera las etapas; aquí se agregará el rol nuevo.
  def operator? = user&.admin?
end

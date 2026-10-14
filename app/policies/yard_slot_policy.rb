class YardSlotPolicy < ApplicationPolicy
  def index? = viewer?
  def show? = viewer?
  def toggle? = user&.admin?

  class Scope < Scope
    def resolve
      user&.admin? || user&.seguridad? ? scope.all : scope.none
    end
  end

  private

  def viewer? = user&.admin? || user&.seguridad?
end

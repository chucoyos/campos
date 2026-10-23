class YardAreaPolicy < ApplicationPolicy
  def index? = viewer?
  def show? = viewer?
  def create? = user&.admin?
  def update? = user&.admin?
  def destroy? = user&.admin?

  class Scope < Scope
    def resolve
      user&.admin? || user&.seguridad? ? scope.all : scope.none
    end
  end

  private

  def viewer? = user&.admin? || user&.seguridad?
end

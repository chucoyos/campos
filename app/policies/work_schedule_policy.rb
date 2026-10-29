class WorkSchedulePolicy < ApplicationPolicy
  def index? = admin?
  def show? = admin?
  def create? = admin?
  def cancel? = admin? && record.activa?

  class Scope < Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end

  private

  def admin? = user&.admin?
end

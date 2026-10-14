class YardAreaPolicy < ApplicationPolicy
  def index? = user&.admin? || user&.seguridad?
  def update? = user&.admin?
end

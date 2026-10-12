# Vincula y desvincula usuarios de un Client o Carrier (la relación vive en users.client_id / users.carrier_id).
module ManagesRelatedUsers
  extend ActiveSupport::Concern

  def link_user
    user = linkable_users.find_by(id: params[:user_id])
    if user&.update(owner_foreign_key => owner.id)
      redirect_to owner, notice: t("shared.related_users.linked", email: user.email)
    else
      redirect_to owner, alert: t("shared.related_users.link_failed")
    end
  end

  def unlink_user
    user = owner.users.find(params[:user_id])
    user.update!(owner_foreign_key => nil)
    redirect_to owner, notice: t("shared.related_users.unlinked", email: user.email)
  end

  private

  def owner_foreign_key = :"#{owner.class.model_name.singular}_id"

  def linkable_users
    User.where(role: owner.class::USER_ROLE, owner_foreign_key => nil)
  end
end

class CarriersController < ApplicationController
  include ManagesRelatedUsers

  before_action :set_carrier, only: %i[show edit update destroy link_user unlink_user]

  def index
    authorize Carrier
    @pagy, @carriers = paginate(apply_filters(policy_scope(Carrier)).order(:name))
  end

  def show
    @users = @carrier.users.order(:email)
    @linkable_users = User.where(role: Carrier::USER_ROLE, carrier_id: nil).order(:email)
  end

  def new
    @carrier = Carrier.new
    authorize @carrier
  end

  def create
    @carrier = Carrier.new(carrier_params)
    authorize @carrier

    if @carrier.save
      redirect_to carriers_path, notice: t("flash.carriers.create")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @carrier.update(carrier_params)
      redirect_to carriers_path, notice: t("flash.carriers.update")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @carrier.destroy
    redirect_to carriers_path, notice: t("flash.carriers.destroy")
  end

  private

  def filter_fields
    [
      { name: "q", type: :text, label: Carrier.human_attribute_name(:name),
        apply: ->(scope, value) { scope.where("carriers.name ILIKE ?", like(value)) } }
    ]
  end

  def owner = @carrier

  def set_carrier
    @carrier = Carrier.find(params[:id])
    authorize @carrier
  end

  def carrier_params
    params.expect(carrier: %i[name])
  end
end

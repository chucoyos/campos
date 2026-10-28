class ClientsController < ApplicationController
  include ManagesRelatedUsers

  before_action :set_client, only: %i[show edit update destroy link_user unlink_user]

  def index
    authorize Client
    @pagy, @clients = paginate(apply_filters(policy_scope(Client)).order(:name))
  end

  def show
    @users = @client.users.order(:email)
    @linkable_users = User.where(role: User::EXTERNAL_ROLES, client_id: nil).order(:email)
  end

  def new
    @client = Client.new
    authorize @client
  end

  def create
    @client = Client.new(client_params)
    authorize @client

    if @client.save
      redirect_to clients_path, notice: t("flash.clients.create")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @client.update(client_params)
      redirect_to(params[:from] == "show" ? @client : clients_path, notice: t("flash.clients.update"))
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @client.destroy
      redirect_to clients_path, notice: t("flash.clients.destroy")
    else
      redirect_to @client, alert: t("flash.clients.destroy_restricted")
    end
  end

  private

  def filter_fields
    [
      { name: "q", type: :text, label: Client.human_attribute_name(:name),
        apply: ->(scope, value) { scope.where("clients.name ILIKE ?", like(value)) } }
    ]
  end

  def owner = @client

  def set_client
    @client = Client.find(params[:id])
    authorize @client
  end

  def client_params
    params.expect(client: %i[name container_color])
  end
end

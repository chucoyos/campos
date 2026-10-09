class ClientsController < ApplicationController
  before_action :set_client, only: %i[show edit update destroy]

  def index
    authorize Client
    @clients = policy_scope(Client).order(:name)
  end

  def show
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
      redirect_to clients_path, notice: t("flash.clients.update")
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

  def set_client
    @client = Client.find(params[:id])
    authorize @client
  end

  def client_params
    params.expect(client: %i[name])
  end
end

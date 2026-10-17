class CargoManifestsController < ApplicationController
  include CargoManifestData

  before_action :set_cargo_manifest, only: %i[show edit update destroy template import confirm reopen]

  def index
    authorize CargoManifest
    @pagy, @cargo_manifests = paginate(policy_scope(CargoManifest).with_items_count.includes(:client, :container).order(created_at: :desc))
  end

  def show
    load_show_data
    @events = @cargo_manifest.events.includes(:user).order(created_at: :desc, id: :desc) if policy(@cargo_manifest).history?
  end

  def new
    @cargo_manifest = CargoManifest.new
    @cargo_manifest.client = current_user.client if current_user.cliente?
    authorize @cargo_manifest
    load_form_options
  end

  def create
    @cargo_manifest = CargoManifest.new(cargo_manifest_params)
    @cargo_manifest.client_id = current_user.client_id if current_user.cliente?
    authorize @cargo_manifest

    if @cargo_manifest.save
      redirect_to(params[:return_to] == "container" && @cargo_manifest.container ? @cargo_manifest.container : @cargo_manifest,
        notice: t("flash.cargo_manifests.create"))
    else
      load_form_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @cargo_manifest, :update?
    load_form_options
  end

  def update
    authorize @cargo_manifest, :update?
    if @cargo_manifest.update(cargo_manifest_params)
      redirect_to @cargo_manifest, notice: t("flash.cargo_manifests.update")
    else
      load_form_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @cargo_manifest, :destroy?
    if @cargo_manifest.destroy
      redirect_to cargo_manifests_path, notice: t("flash.cargo_manifests.destroy")
    else
      redirect_to @cargo_manifest, alert: @cargo_manifest.errors.full_messages.to_sentence
    end
  end

  def confirm
    authorize @cargo_manifest, :confirm?
    @cargo_manifest.confirm_by!(current_user)
    redirect_back_or_to @cargo_manifest, notice: t("flash.cargo_manifests.confirm")
  rescue AASM::InvalidTransition
    @cargo_manifest.errors.add(:base, :cannot_confirm)
    load_show_data
    render :show, status: :unprocessable_entity
  end

  def reopen
    authorize @cargo_manifest, :reopen?
    @cargo_manifest.reopen_by!(current_user)
    redirect_back_or_to @cargo_manifest, notice: t("flash.cargo_manifests.reopen")
  rescue AASM::InvalidTransition
    redirect_to @cargo_manifest, alert: t("flash.cargo_manifests.invalid_transition")
  end

  def template
    send_data CargoItemSpreadsheet.template, filename: "mercancias_#{template_label}.xlsx",
      type: CargoItemSpreadsheet::CONTENT_TYPE, disposition: "attachment"
  end

  def import
    authorize @cargo_manifest, :update?
    result = CargoItemImporter.new(@cargo_manifest, params[:file]).call
    if result.success?
      redirect_back_or_to @cargo_manifest, notice: t("flash.cargo_manifests.import", count: result.created)
    else
      @import_errors = result.errors
      load_show_data
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_cargo_manifest
    @cargo_manifest = policy_scope(CargoManifest).find(params[:id])
    authorize @cargo_manifest
  end

  def template_label
    @cargo_manifest.container&.number&.parameterize(preserve_case: true) || "carga_general_#{@cargo_manifest.id}"
  end

  def load_show_data
    load_cargo_manifest_data(@cargo_manifest)
  end

  def load_form_options
    @clients = Client.order(:name) if current_user.admin? || current_user.seguridad?
    taken = CargoManifest.where.not(container_id: nil).where.not(id: @cargo_manifest.id).select(:container_id)
    @containers = policy_scope(Container).joins(:master_bl).includes(:master_bl).where.not(id: taken).order(:number)
  end

  def cargo_manifest_params
    permitted = %i[container_id]
    permitted << :client_id if current_user.admin? || current_user.seguridad?
    params.expect(cargo_manifest: permitted)
  end
end

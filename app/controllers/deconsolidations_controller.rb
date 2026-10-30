class DeconsolidationsController < ApplicationController
  def index
    authorize Deconsolidation
    @pagy, @deconsolidations = paginate(
      policy_scope(Deconsolidation).includes(container: :master_bl).includes(container: :cargo_manifest).order(Arel.sql("status = 'vaciado'"), id: :desc)
    )
    manifest_ids = @deconsolidations.filter_map { |deconsolidation| deconsolidation.container.cargo_manifest&.id }
    counts = CargoItem.where(cargo_manifest_id: manifest_ids).group(:cargo_manifest_id, :status).count
    @progress = @deconsolidations.to_h do |deconsolidation|
      manifest_id = deconsolidation.container.cargo_manifest&.id
      stored = counts.fetch([ manifest_id, "stored" ], 0)
      total = counts.select { |(id, _), _| id == manifest_id }.values.sum
      [ deconsolidation.id, [ stored, total ] ]
    end
    @waiting = Container.where.not(master_bl_id: nil).where.missing(:deconsolidation_record)
      .joins(:current_yard_slot).merge(YardSlot.desycon).includes(:master_bl, :current_yard_slot).order(:number)
  end

  def show
    @deconsolidation = policy_scope(Deconsolidation).includes(container: %i[master_bl current_yard_slot]).find(params[:id])
    authorize @deconsolidation
    @pending_items = @deconsolidation.pending_cargo_items.includes(:cargo_packaging).order(:id)
  end

  def labels
    @deconsolidation = policy_scope(Deconsolidation).includes(:container).find(params[:id])
    authorize @deconsolidation
    @items = @deconsolidation.cargo_items.where.not(qr_token: nil).includes(:cargo_packaging, :cargo_manifest).order(:id)
  end

  def create
    authorize Deconsolidation
    deconsolidation = DeconsolidationService.start(container: Container.find(params[:container_id]), user: current_user)
    redirect_to deconsolidation, notice: t("flash.deconsolidations.create")
  rescue DeconsolidationService::Error => error
    redirect_to deconsolidations_path, alert: error.message
  end

  def advance
    deconsolidation = policy_scope(Deconsolidation).find(params[:id])
    authorize deconsolidation
    result = DeconsolidationService.advance(deconsolidation:, user: current_user)
    redirect_to deconsolidation, **advance_flash(result)
  rescue DeconsolidationService::Error => error
    redirect_to deconsolidation, alert: error.message
  end

  private

  def advance_flash(result)
    return { notice: t("flash.deconsolidations.advance.#{result.deconsolidation.status}") } if result.deconsolidation.desconsolidando? || result.deconsolidation.vacio?
    return { notice: t("flash.deconsolidations.advance.vaciado") } if result.rehandle_order

    { alert: t("flash.deconsolidations.advance.vaciado_without_task") }
  end
end

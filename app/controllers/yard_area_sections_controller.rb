class YardAreaSectionsController < ApplicationController
  before_action :set_yard_area
  before_action :set_section, only: %i[update destroy assign_slots release_slots]

  def create
    @section = @yard_area.sections.new(section_params)
    if @section.save
      redirect_to @yard_area, notice: t("flash.yard_area_sections.create")
    else
      redirect_to @yard_area, alert: @section.errors.full_messages.to_sentence
    end
  end

  def update
    if @section.update(section_params)
      redirect_to @yard_area, notice: t("flash.yard_area_sections.update")
    else
      redirect_to @yard_area, alert: @section.errors.full_messages.to_sentence
    end
  end

  def destroy
    @section.destroy
    redirect_to @yard_area, notice: t("flash.yard_area_sections.destroy")
  end

  def assign_slots
    result = @section.assign_slots(**slot_filters)
    redirect_to @yard_area, notice: t("flash.yard_area_sections.assigned", count: result[:assigned], conflicts: result[:conflicts])
  end

  def release_slots
    count = @section.release_slots(**slot_filters)
    redirect_to @yard_area, notice: t("flash.yard_area_sections.released", count: count)
  end

  private

  def set_yard_area
    @yard_area = YardArea.find(params[:yard_area_id])
    authorize @yard_area, :update?
  end

  def set_section
    @section = @yard_area.sections.find(params[:id])
  end

  def section_params
    params.expect(yard_area_section: %i[name master_bl_id active])
  end

  # Rangos de bahía y listas de filas y niveles dentro de las dimensiones del bloque.
  def slot_filters
    block = @yard_area.yard_block
    from = [ params[:bay_from].to_i, 1 ].max
    to = [ params[:bay_to].presence&.to_i || from, block.bays ].min
    {
      bays: (from..to).to_a,
      rows: Array(params[:rows]) & block.row_letters,
      levels: Array(params[:levels]).map(&:to_i) & (1..block.levels).to_a
    }
  end
end

class YardAreasController < ApplicationController
  before_action :set_yard_area, only: %i[show edit update destroy]

  def index
    authorize YardArea
    @pagy, @yard_areas = paginate(apply_filters(policy_scope(YardArea).includes(:yard_block, :client)).order(:code))
  end

  def show
    @sections = @yard_area.sections.includes(:master_bl).order(:name)
    @slot_counts = YardSlot.where(yard_area_section_id: @sections.map(&:id)).group(:yard_area_section_id).count
    @summaries = slot_summaries(@sections)
    @master_bls = @yard_area.client ? @yard_area.client.master_bls.order(:number) : MasterBl.none
  end

  def new
    @yard_area = YardArea.new
    authorize @yard_area
  end

  def create
    @yard_area = YardArea.new(yard_area_params)
    authorize @yard_area

    if @yard_area.save
      redirect_to @yard_area, notice: t("flash.yard_areas.create")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @yard_area.update(yard_area_params)
      redirect_to @yard_area, notice: t("flash.yard_areas.update")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @yard_area.destroy
      redirect_to yard_areas_path, notice: t("flash.yard_areas.destroy")
    else
      redirect_to @yard_area, alert: t("flash.yard_areas.destroy_restricted")
    end
  end

  private

  def filter_fields
    [
      { name: "q", type: :text, label: YardArea.human_attribute_name(:name),
        apply: ->(scope, value) { scope.where("yard_areas.name ILIKE :q OR yard_areas.code ILIKE :q", q: like(value)) } }
    ]
  end

  # Por sección: [nivel, fila, "bahías"] con rangos contiguos compactados (1-4, 7).
  def slot_summaries(sections)
    rows = YardSlot.where(yard_area_section_id: sections.map(&:id)).order(:level, :row, :bay).pluck(:yard_area_section_id, :level, :row, :bay)
    rows.group_by { |section_id, level, row, _| [ section_id, level, row ] }.each_with_object({}) do |((section_id, level, row), items), result|
      (result[section_id] ||= []) << [ level, row, compact_ranges(items.map(&:last)) ]
    end
  end

  def compact_ranges(numbers)
    numbers.slice_when { |a, b| b != a + 1 }.map { |run| run.size > 1 ? "#{run.first}-#{run.last}" : run.first.to_s }.join(", ")
  end

  def set_yard_area
    @yard_area = YardArea.find(params[:id])
    authorize @yard_area
  end

  def yard_area_params
    params.expect(yard_area: %i[code name yard_block_id client_id active])
  end
end

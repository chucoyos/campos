class YardController < ApplicationController
  def index
    authorize YardSlot
    @blocks = YardBlock.order(:code)
    @slot_counts = YardSlot.group(:yard_block_id, :enabled).count
    @disabled_codes = YardSlot.where(enabled: false).pluck(:code)
    occupied = Container.where.not(current_yard_slot_id: nil)
      .joins(:current_yard_slot)
      .where(yard_slots: { yard_block_id: @blocks.select(:id) })
      .includes(:master_bl, current_yard_slot: :yard_block)
      .order(:number).to_a
    colors = Client.where(id: occupied.filter_map(&:owner_client_id).uniq).pluck(:id, :container_color).to_h
    @occupied_containers = occupied.map do |container|
      slot = container.current_yard_slot
      { number: container.number, size: container.size, code: slot.code, block: slot.yard_block.code,
          bay: slot.bay, row: slot.row, level: slot.level, color: colors[container.owner_client_id],
          status: I18n.t("containers.statuses.#{container.status}", default: container.status.to_s) }
    end
    @sections_map = sections_map
    @pagy, @slots = paginate(apply_filters(policy_scope(YardSlot)).eager_load(:yard_block).order("yard_blocks.code", :level, :row, :bay))
  end

  private

  SECTION_COLORS = %w[#e11d48 #0ea5e9 #84cc16 #a855f7 #f97316 #14b8a6 #ec4899 #eab308 #3b82f6 #64748b].freeze

  # Secciones activas con su color y las posiciones que agrupan, para el modo "Áreas" del mapa.
  def sections_map
    sections = YardAreaSection.active.joins(:yard_area).merge(YardArea.active)
                              .includes(:master_bl, yard_area: :client).order("yard_areas.code", :name)
    codes = YardSlot.where(yard_area_section_id: sections.map(&:id)).pluck(:yard_area_section_id, :code).group_by(&:first)
    sections.each_with_index.map do |section, index|
      area = section.yard_area
      detail = [ area.client&.name, section.master_bl&.number ].compact.join(" · ")
      { label: "#{area.code} · #{section.name}", detail: detail, color: SECTION_COLORS[index % SECTION_COLORS.size],
        slots: codes.fetch(section.id, []).map(&:last) }
    end
  end

  def filter_fields
    [
      { name: "block", type: :select, label: YardBlock.model_name.human,
        options: YardBlock.order(:code).pluck(:code).map { |code| [ code, code ] },
        apply: ->(scope, value) { scope.joins(:yard_block).where(yard_blocks: { code: value }) } },
      { name: "row", type: :select, label: YardSlot.human_attribute_name(:row),
        options: ("A".."L").map { |row| [ row, row ] },
        apply: ->(scope, value) { scope.where(row: value) } },
      { name: "level", type: :select, label: YardSlot.human_attribute_name(:level),
        options: (1..YardBlock.maximum(:levels).to_i).map { |level| [ level.to_s, level.to_s ] },
        apply: ->(scope, value) { scope.where(level: value) } },
      { name: "enabled", type: :select, label: YardSlot.human_attribute_name(:enabled),
        options: [ [ t("yard.states.enabled"), "true" ], [ t("yard.states.disabled"), "false" ] ],
        apply: ->(scope, value) { scope.where(enabled: value == "true") } }
    ]
  end
end

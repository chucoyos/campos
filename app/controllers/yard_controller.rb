class YardController < ApplicationController
  def index
    authorize YardSlot
    @blocks = YardBlock.order(:code)
    @areas = YardArea.order(:code)
    @slot_counts = YardSlot.group(:yard_block_id, :enabled).count
    @disabled_codes = YardSlot.where(enabled: false).pluck(:code)
    @pagy, @slots = paginate(apply_filters(policy_scope(YardSlot)).eager_load(:yard_block).order("yard_blocks.code", :level, :row, :bay))
  end

  private

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

class YardSlot < ApplicationRecord
  belongs_to :yard_block
  belongs_to :yard_area_section, optional: true

  before_validation :build_code

  validates :bay, :level, numericality: { only_integer: true, greater_than: 0 }
  validates :row, presence: true, format: { with: /\A[A-Z]\z/, allow_blank: true }
  validates :code, uniqueness: true
  validates :bay, uniqueness: { scope: %i[yard_block_id row level] }
  validate :position_within_block

  scope :enabled, -> { where(enabled: true) }

  # Un contenedor de 40 pies ocupa dos bahías contiguas y se ancla en la bahía impar.
  def forty_foot_anchor?
    bay.to_i.odd?
  end

  private

  def build_code
    self.code = "#{yard_block&.code}#{bay}#{row}#{level}" if yard_block && bay && row && level
  end

  def position_within_block
    return unless yard_block

    errors.add(:bay, :out_of_block) if bay.to_i > yard_block.bays
    errors.add(:row, :out_of_block) if row.present? && yard_block.row_letters.exclude?(row)
    errors.add(:level, :out_of_block) if level.to_i > yard_block.levels
  end
end

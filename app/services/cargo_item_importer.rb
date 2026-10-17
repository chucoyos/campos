require "roo"

class CargoItemImporter
  MAX_ROWS = 2_000
  MAX_FILE_SIZE = 5.megabytes
  TRUE_VALUES = %w[si sí yes true 1].freeze
  FALSE_VALUES = %w[no false 0].freeze

  Result = Struct.new(:created, :errors, keyword_init: true) do
    def success? = errors.empty?
  end

  def initialize(cargo_manifest, file)
    @cargo_manifest = cargo_manifest
    @file = file
  end

  def call
    return failure(I18n.t("cargo_import.errors.no_file")) if @file.blank?
    return failure(I18n.t("cargo_import.errors.invalid_file")) unless valid_file?
    return failure(I18n.t("cargo_import.errors.closed")) unless @cargo_manifest.draft?

    rows = read_rows
    return failure(I18n.t("cargo_import.errors.empty")) if rows.empty?
    return failure(I18n.t("cargo_import.errors.too_many", max: MAX_ROWS)) if rows.size > MAX_ROWS

    save(rows)
  rescue Zip::Error, ArgumentError, IOError, Roo::HeaderRowNotFoundError, Nokogiri::XML::SyntaxError
    failure(I18n.t("cargo_import.errors.invalid_file"))
  end

  private

  def valid_file?
    File.extname(@file.original_filename.to_s).casecmp?(".xlsx") && @file.size <= MAX_FILE_SIZE
  end

  def read_rows
    sheet = Roo::Excelx.new(@file.path, extension: :xlsx).sheet(0)
    return [] unless sheet.last_row

    (2..sheet.last_row).filter_map do |row_number|
      values = sheet.row(row_number).first(CargoItemSpreadsheet::COLUMN_COUNT)
      [ row_number, *values ] if values.any?(&:present?)
    end
  end

  def save(rows)
    errors = []
    created = 0

    CargoItem.transaction do
      rows.each do |row_number, packaging_value, description, quantity, weight_value, origin_identifier, qr_value|
        packaging = find_packaging(packaging_value)
        weight = parse_decimal(weight_value)
        qr_choice = I18n.transliterate(qr_value.to_s.strip.downcase)
        item = @cargo_manifest.cargo_items.build(
          cargo_packaging: packaging,
          description: description,
          quantity: parse_integer(quantity),
          weight_kg: weight,
          origin_identifier: origin_identifier,
          generate_qr: TRUE_VALUES.include?(qr_choice)
        )
        item.valid?
        item.errors.add(:cargo_packaging, :blank) if packaging.nil? && item.errors[:cargo_packaging].empty?
        item.errors.add(:weight_kg, :not_a_number) if weight_value.present? && weight.nil?
        item.errors.add(:generate_qr, :inclusion) if qr_value.present? && !TRUE_VALUES.include?(qr_choice) && !FALSE_VALUES.include?(qr_choice)

        if item.errors.empty? && item.save(validate: false)
          created += 1
        else
          errors << row_error(row_number, item)
        end
      end
      raise ActiveRecord::Rollback if errors.any?
    end

    Result.new(created: errors.empty? ? created : 0, errors: errors)
  end

  def find_packaging(value)
    key = value.to_s.strip.downcase
    return if key.blank?

    @packagings ||= CargoPackaging.active.to_a
    @packagings.find { |packaging| packaging.code == key || packaging.name.downcase == key }
  end

  def parse_integer(value)
    Integer(value.to_s.strip.delete_suffix(".0"), exception: false)
  end

  def parse_decimal(value)
    return if value.blank?

    parsed = BigDecimal(value.to_s.strip.tr(",", "."), exception: false)
    parsed if parsed&.finite?
  end

  def row_error(row, item)
    I18n.t("cargo_import.errors.row", row: row, messages: item.errors.full_messages.to_sentence)
  end

  def failure(message)
    Result.new(created: 0, errors: [ message ])
  end
end

require "roo"

# Crea los contenedores de un MBL a partir de un Excel. Es todo o nada:
# si alguna fila es inválida no se guarda ninguna.
class ContainerImporter
  MAX_ROWS = 500
  MAX_FILE_SIZE = 2.megabytes
  TYPE_ALIASES = { "standard" => "standard", "estandar" => "standard", "hq" => "hq" }.freeze

  Result = Struct.new(:created, :errors, keyword_init: true) do
    def success? = errors.empty?
  end

  def initialize(master_bl, file)
    @master_bl = master_bl
    @file = file
  end

  def call
    return failure(I18n.t("container_import.errors.no_file")) if @file.blank?
    return failure(I18n.t("container_import.errors.invalid_file")) unless valid_file?

    rows = read_rows
    return failure(I18n.t("container_import.errors.empty")) if rows.empty?
    return failure(I18n.t("container_import.errors.too_many", max: MAX_ROWS)) if rows.size > MAX_ROWS

    save(rows)
  rescue Zip::Error, ArgumentError, IOError, Roo::HeaderRowNotFoundError, Nokogiri::XML::SyntaxError
    failure(I18n.t("container_import.errors.invalid_file"))
  end

  private

  def valid_file?
    File.extname(@file.original_filename.to_s).casecmp?(".xlsx") && @file.size <= MAX_FILE_SIZE
  end

  def read_rows
    sheet = Roo::Excelx.new(@file.path, extension: :xlsx).sheet(0)
    return [] unless sheet.last_row

    (2..sheet.last_row).filter_map do |index|
      values = sheet.row(index).first(3)
      [ index, *values ] if values.any?(&:present?)
    end
  end

  def save(rows)
    errors = []

    Container.transaction do
      rows.each do |index, number, size, type|
        container = @master_bl.containers.build(number: number.to_s, size: parse_size(size), container_type: parse_type(type))
        next if container.save

        errors << I18n.t("container_import.errors.row", row: index, messages: container.errors.full_messages.to_sentence)
      end
      raise ActiveRecord::Rollback if errors.any?
    end

    Result.new(created: errors.empty? ? rows.size : 0, errors: errors)
  end

  def parse_size(value)
    Integer(value.to_s.strip.delete_suffix(".0"), exception: false)
  end

  def parse_type(value)
    key = I18n.transliterate(value.to_s).strip.downcase
    TYPE_ALIASES.fetch(key, key.presence)
  end

  def failure(message)
    Result.new(created: 0, errors: [ message ])
  end
end

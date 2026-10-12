class MasterBl < ApplicationRecord
  belongs_to :client
  has_many :containers, dependent: :restrict_with_error
  has_one_attached :document

  DOCUMENT_CONTENT_TYPES = %w[application/pdf].freeze
  DOCUMENT_MAX_SIZE = 10.megabytes

  normalizes :number, with: ->(number) { number.strip.upcase }

  validates :number, presence: true, uniqueness: true
  validate :document_is_valid_pdf

  private

  def document_is_valid_pdf
    return unless document.attached?

    errors.add(:document, :invalid_type) unless DOCUMENT_CONTENT_TYPES.include?(document.blob.content_type)
    errors.add(:document, :too_large, max: DOCUMENT_MAX_SIZE / 1.megabyte) if document.blob.byte_size > DOCUMENT_MAX_SIZE
  end
end

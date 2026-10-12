class User < ApplicationRecord
  ROLES = %w[admin cliente transporte seguridad grua montacargas].freeze

  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  enum :role, ROLES.index_with(&:itself), validate: true

  belongs_to :client, optional: true
  belongs_to :carrier, optional: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  before_validation :clear_unrelated_links

  validates :role, presence: true

  # Cliente o transportista al que pertenece el usuario (nil para roles internos).
  def entity
    client || carrier
  end

  private

  # Solo los usuarios cliente se vinculan a un Client y solo los de transporte a un Carrier.
  def clear_unrelated_links
    self.client_id = nil unless cliente?
    self.carrier_id = nil unless transporte?
  end
end

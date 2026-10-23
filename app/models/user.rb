class User < ApplicationRecord
  ROLES = %w[admin cliente transporte seguridad grua montacargas].freeze

  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  enum :role, ROLES.index_with(&:itself), validate: true

  belongs_to :client, optional: true
  belongs_to :carrier, optional: true

  normalizes :email, with: ->(email) { email.strip.downcase }

  before_validation :clear_unrelated_links

  validates :role, presence: true

  EXTERNAL_ROLES = %w[cliente transporte].freeze

  def client_member? = EXTERNAL_ROLES.include?(role) && client_id.present?
  def carrier_member? = EXTERNAL_ROLES.include?(role) && carrier_id.present?

  # Afiliaciones del usuario como pares [icono, entidad] (puede tener cliente y transportista).
  def entities
    [ [ "person_search", client ], [ "local_shipping", carrier ] ].reject { |_, entity| entity.nil? }
  end

  # Cliente o transportista al que pertenece el usuario (nil para roles internos).
  def entity
    client || carrier
  end

  private

  # Los roles internos no se vinculan a empresas; cliente y transporte pueden tener ambas afiliaciones.
  def clear_unrelated_links
    return if cliente? || transporte?

    self.client_id = nil
    self.carrier_id = nil
  end
end

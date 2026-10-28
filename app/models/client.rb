class Client < ApplicationRecord
  USER_ROLE = "cliente".freeze

  has_many :users, dependent: :nullify
  has_many :containers, dependent: :restrict_with_error
  has_many :master_bls, dependent: :restrict_with_error
  has_many :cargo_manifests, dependent: :restrict_with_error

  COLOR_FORMAT = /\A#\h{6}\z/

  normalizes :name, with: ->(name) { name.strip }
  normalizes :container_color, with: ->(color) { color.to_s.strip.downcase.presence }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :container_color, format: { with: COLOR_FORMAT }, allow_nil: true
end

class EventType < ApplicationRecord
  HEX_COLOR = /\A#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  has_many :events, dependent: :restrict_with_error

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { case_sensitive: false },
                   format: { with: SLUG_FORMAT }
  validates :color, presence: true,
                    format: { with: HEX_COLOR, message: "must be a hex colour like #6b3f7a" }

  normalizes :slug, with: ->(slug) { slug.to_s.strip.downcase }

  scope :alphabetical, -> { order(:name) }
end

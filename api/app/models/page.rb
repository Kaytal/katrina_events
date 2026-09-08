# One row per static page: home, about, contact. Body is Markdown, authored by
# Katrina in the admin editor (Phase 4) and rendered on the client.
class Page < ApplicationRecord
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  validates :slug,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: SLUG_FORMAT, message: "must be lowercase letters, numbers, and dashes" }
  validates :title, presence: true
  validates :meta_description, length: { maximum: 320 }, allow_blank: true

  normalizes :slug, with: ->(slug) { slug.to_s.strip.downcase }

  scope :published, -> { where.not(published_at: nil).where(published_at: ..Time.current) }

  def published?
    published_at.present? && published_at <= Time.current
  end
end

class Venue < ApplicationRecord
  has_many :events, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  # Anchored at both ends and rejecting whitespace: with only a leading \A, a
  # value like "https://ok.example\nanything" validates, and the tail comes
  # along wherever the URL is later rendered or followed.
  validates :url,
            format: { with: %r{\Ahttps?://\S+\z}, message: "must be a full http:// or https:// URL" },
            allow_blank: true
end

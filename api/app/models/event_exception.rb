# One deviation from a recurring event's rule. See the migration for why
# `original_date` is a local date rather than a timestamp.
class EventException < ApplicationRecord
  SKIP = "skip"
  MOVE = "move"
  ACTIONS = [ SKIP, MOVE ].freeze

  belongs_to :event

  validates :original_date, presence: true, uniqueness: { scope: :event_id }
  validates :action, presence: true, inclusion: { in: ACTIONS }

  with_options if: :move? do
    validates :starts_at, presence: true
    validates :ends_at, presence: true
    validate :ends_after_starts
  end

  validate :skip_carries_no_times, if: :skip?

  # Moves whose *destination* falls in a window. A moved occurrence can land
  # inside the window even when the date its rule produced sits outside it.
  scope :moved_into, lambda { |from, to|
    where(action: MOVE).where("starts_at < ? AND ends_at > ?", to, from)
  }

  def skip?
    action == SKIP
  end

  def move?
    action == MOVE
  end

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after the start time") if ends_at <= starts_at
  end

  def skip_carries_no_times
    return if starts_at.blank? && ends_at.blank?

    errors.add(:base, "a skipped occurrence cannot also have a new time")
  end
end

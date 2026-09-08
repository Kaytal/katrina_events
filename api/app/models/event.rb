# Everything visible on the calendar. What differs between an announcement and a
# class is `bookable`, not the table.
class Event < ApplicationRecord
  SCHEDULED = "scheduled"
  CANCELLED = "cancelled"
  STATUSES = [ SCHEDULED, CANCELLED ].freeze

  belongs_to :event_type
  belongs_to :venue, optional: true
  has_many :event_exceptions, dependent: :destroy

  validates :title, presence: true
  validates :starts_at, :ends_at, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :capacity, numericality: { greater_than: 0 }, allow_nil: true

  validate :ends_after_starts
  validate :recurrence_rule_is_parseable
  validate :bookable_events_have_capacity

  scope :scheduled, -> { where(status: SCHEDULED) }
  scope :recurring, -> { where.not(recurrence_rule: nil) }

  # Events that could plausibly place an occurrence inside [from, to]: either a
  # one-off overlapping the window, or a recurring event whose rule has not
  # already run out before it. Narrowing in SQL keeps expansion off every row in
  # the table; the expansion itself decides what actually lands in the window.
  scope :possibly_within, lambda { |from, to|
    one_off = where(recurrence_rule: nil).where("starts_at < ? AND ends_at > ?", to, from)

    recurring = where.not(recurrence_rule: nil)
                     .where("starts_at < ?", to)
                     .where("recurrence_until IS NULL OR recurrence_until >= ?", from)

    # An occurrence moved into the window counts even when the event's own rule
    # has nothing there — a class shifted from April into May is a May event.
    moved_in = where(id: EventException.moved_into(from, to).select(:event_id))

    one_off.or(recurring).or(moved_in)
  }

  def recurring?
    recurrence_rule.present?
  end

  def duration
    ends_at - starts_at
  end

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after the start time") if ends_at <= starts_at
  end

  def recurrence_rule_is_parseable
    return if recurrence_rule.blank?

    IceCube::Rule.from_ical(recurrence_rule)
  rescue StandardError
    # ice_cube raises a variety of classes for malformed input; the useful
    # outcome either way is a validation message rather than a 500 at render.
    errors.add(:recurrence_rule, "is not a valid RRULE")
  end

  # A bookable event with no capacity would generate a block nobody can be
  # approved into, or an unbounded one — neither is a thing she means.
  def bookable_events_have_capacity
    return unless bookable?

    errors.add(:capacity, "is required for a bookable event") if capacity.blank?
  end
end

# The concrete bookable unit. A request points at one of these.
class TimeBlock < ApplicationRecord
  OPEN = "open"
  CLOSED = "closed"
  FULL = "full"
  STATUSES = [ OPEN, CLOSED, FULL ].freeze

  belongs_to :availability_pattern, optional: true
  belongs_to :event, optional: true
  belongs_to :event_type
  belongs_to :venue, optional: true

  validates :starts_at, :ends_at, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :capacity, numericality: { greater_than: 0 }, allow_nil: true

  validate :ends_after_starts
  validate :single_source
  validate :override_not_below_approved

  scope :open, -> { where(status: OPEN) }
  scope :bookable_between, lambda { |from, to|
    open.where("starts_at < ? AND ends_at > ?", to, from)
  }
  scope :from_event, ->(event) { where(event: event) }
  scope :from_pattern, ->(pattern) { where(availability_pattern: pattern) }
  scope :starting_after, ->(time) { where("starts_at >= ?", time) }
  scope :needing_review, -> { where(needs_review: true) }

  def source
    availability_pattern || event
  end

  # Null means inherit. Reading the raw column anywhere else is a bug: raising a
  # class from 12 to 15 has to reach every block that has not been deliberately
  # overridden, and copying values down at generation time would not.
  def effective_capacity
    capacity || source&.capacity
  end

  def effective_price_note
    price_note || source&.price_note
  end

  def overridden?
    capacity.present? || price_note.present?
  end

  def open?
    status == OPEN
  end

  # PHASE 8 — booking_requests does not exist yet. Everything that needs to know
  # how many people are in a block goes through these two methods, so wiring the
  # real association is a change in one place rather than a hunt.
  #
  # They are not decoration: the protection rule and the override floor below
  # are written against them and specced by stubbing them, so the logic that
  # matters this phase is real and tested today.
  def approved_count
    0
  end

  def requested_count
    0
  end

  def spots_remaining
    return nil if effective_capacity.nil?

    [ effective_capacity - approved_count, 0 ].max
  end

  # A block regeneration is not allowed to delete or silently move. §2: a block
  # with requests is never destroyed — it is left in place and flagged.
  def protected_from_regeneration?
    requested_count.positive?
  end

  def flag_for_review!(reason)
    update_columns(needs_review: true, review_reason: reason, updated_at: Time.current)
  end

  private

  def ends_after_starts
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after the start time") if ends_at <= starts_at
  end

  def single_source
    return unless availability_pattern_id.present? && event_id.present?

    errors.add(:base, "a block comes from a pattern or an event, never both")
  end

  # She must not be able to un-approve someone by editing a number. Closing the
  # block is the action she actually wants there, so the message says so.
  def override_not_below_approved
    return if capacity.blank?

    approved = approved_count
    return if capacity >= approved

    errors.add(:capacity,
               "cannot be below the #{approved} already approved. " \
               "Close the block instead if you need to stop new requests")
  end
end

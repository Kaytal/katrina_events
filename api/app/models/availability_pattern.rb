# "Tuesdays 4–6pm, 30-minute slots, one at a time." She edits this; the app
# materializes concrete time_blocks from it, because a request has to point at a
# row that exists and an expanded rule is not a row.
class AvailabilityPattern < ApplicationRecord
  belongs_to :event_type
  belongs_to :venue, optional: true
  # NOT :nullify. A block with no source is a legitimate thing — she can make
  # one by hand — which is exactly why nullifying is dangerous: destroying a
  # pattern would silently convert its slots into hand-made ones that nothing
  # regenerates and nothing ever cleans up, and no constraint would complain.
  # Deletion has to go through the path that retires the blocks first
  # (Mutations::DeleteAvailabilityPattern), which honours the protection rule.
  has_many :time_blocks, dependent: :restrict_with_error

  validates :weekday, presence: true, inclusion: { in: 0..6 }
  validates :start_time, :end_time, :effective_from, presence: true
  validates :slot_minutes, numericality: { greater_than: 0, less_than_or_equal_to: 480 }
  validates :capacity, numericality: { greater_than: 0 }

  validate :ends_after_starts
  validate :slots_divide_evenly
  validate :effective_range_is_ordered

  scope :active, -> { where(active: true) }

  # Patterns that could produce a slot inside [from, to].
  scope :effective_between, lambda { |from, to|
    where(effective_from: ..to.to_date)
      .where("effective_to IS NULL OR effective_to >= ?", from.to_date)
  }

  def slot_count
    return 0 if start_time.blank? || end_time.blank? || slot_minutes.to_i.zero?

    ((end_time - start_time) / 60 / slot_minutes).floor
  end

  def covers?(date)
    return false unless active?
    return false unless date.wday == weekday
    return false if effective_from.present? && date < effective_from
    return false if effective_to.present? && date > effective_to

    true
  end

  private

  def ends_after_starts
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, "must be after the start time") if end_time <= start_time
  end

  # A 4–6pm window at 45 minutes would silently drop the last 30 minutes.
  # Better to say so than to quietly lose availability she thinks she offered.
  def slots_divide_evenly
    return if start_time.blank? || end_time.blank? || slot_minutes.to_i <= 0
    return if end_time <= start_time

    minutes = (end_time - start_time) / 60
    return if (minutes % slot_minutes).zero?

    errors.add(:slot_minutes,
               "does not divide the window evenly — #{minutes.to_i} minutes " \
               "leaves #{(minutes % slot_minutes).to_i} minutes over")
  end

  def effective_range_is_ordered
    return if effective_from.blank? || effective_to.blank?

    errors.add(:effective_to, "must be on or after the start date") if effective_to < effective_from
  end
end

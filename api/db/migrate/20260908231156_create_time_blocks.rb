# The concrete bookable unit a request points at. Materialized from a pattern,
# generated from a bookable event's occurrence, or made one-off by hand.
class CreateTimeBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :time_blocks do |t|
      t.references :availability_pattern, null: true, foreign_key: true
      t.references :event, null: true, foreign_key: true
      t.references :event_type, null: false, foreign_key: true
      t.references :venue, null: true, foreign_key: true

      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false

      # The local date of the event occurrence this block came from. Identity
      # for event-generated blocks: a moved occurrence keeps its original_date,
      # so regeneration updates the same row rather than orphaning it and
      # making a new one. Null for pattern and hand-made blocks, which are
      # identified by starts_at.
      t.date :original_date

      # NULL MEANS INHERIT from the parent event or pattern. A value is a
      # deliberate override for this one occurrence. Read effective_capacity /
      # effective_price_note, never these columns.
      t.integer :capacity
      t.string :price_note

      t.string :status, null: false, default: "open"
      t.text :notes

      # Set when regeneration wanted to change or remove a block it is not
      # allowed to touch. Left in place, flagged, for her to resolve.
      t.boolean :needs_review, null: false, default: false
      t.string :review_reason

      t.timestamps
    end

    add_index :time_blocks, :starts_at
    add_index :time_blocks, [ :status, :starts_at ]
    # Regeneration is keyed on these, so they have to be unique as well as fast.
    add_index :time_blocks, [ :event_id, :original_date ], unique: true,
              where: "event_id IS NOT NULL"
    add_index :time_blocks, [ :availability_pattern_id, :starts_at ], unique: true,
              where: "availability_pattern_id IS NOT NULL"

    add_check_constraint :time_blocks, "ends_at > starts_at",
                         name: "time_blocks_end_after_start"
    add_check_constraint :time_blocks, "capacity IS NULL OR capacity > 0",
                         name: "time_blocks_capacity_positive"
    add_check_constraint :time_blocks, "status IN ('open', 'closed', 'full')",
                         name: "time_blocks_status_valid"
    # A block comes from a pattern, or an event, or neither (hand-made) —
    # never both. Two sources means two owners of its capacity and its times.
    add_check_constraint :time_blocks,
                         "NOT (availability_pattern_id IS NOT NULL AND event_id IS NOT NULL)",
                         name: "time_blocks_single_source"
    # original_date only means something for an event-generated block.
    add_check_constraint :time_blocks,
                         "original_date IS NULL OR event_id IS NOT NULL",
                         name: "time_blocks_original_date_needs_event"
  end
end

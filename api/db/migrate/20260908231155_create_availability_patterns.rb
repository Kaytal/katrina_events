# The template she edits: "Tuesdays 4–6pm, 30-minute slots, one at a time."
# The app materializes concrete time_blocks from it; a request always points at
# a row that exists, never at an expanded rule.
class CreateAvailabilityPatterns < ActiveRecord::Migration[8.1]
  def change
    create_table :availability_patterns do |t|
      t.references :event_type, null: false, foreign_key: true
      t.references :venue, null: true, foreign_key: true

      # 0 = Sunday, matching Ruby's Date#wday.
      t.integer :weekday, null: false
      # Wall-clock times in America/Denver. `time` columns carry no date, which
      # is the point — the pattern is a weekly shape, not an instant.
      t.time :start_time, null: false
      t.time :end_time, null: false
      t.integer :slot_minutes, null: false, default: 30
      t.integer :capacity, null: false, default: 1

      t.date :effective_from, null: false
      t.date :effective_to
      t.boolean :active, null: false, default: true

      t.string :price_note

      t.timestamps
    end

    add_index :availability_patterns, [ :active, :weekday ]

    add_check_constraint :availability_patterns, "end_time > start_time",
                         name: "availability_patterns_end_after_start"
    add_check_constraint :availability_patterns, "weekday BETWEEN 0 AND 6",
                         name: "availability_patterns_weekday_valid"
    add_check_constraint :availability_patterns, "slot_minutes > 0",
                         name: "availability_patterns_slot_positive"
    add_check_constraint :availability_patterns, "capacity > 0",
                         name: "availability_patterns_capacity_positive"
    add_check_constraint :availability_patterns,
                         "effective_to IS NULL OR effective_to >= effective_from",
                         name: "availability_patterns_range_valid"
  end
end

class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :event_type, null: false, foreign_key: true
      t.references :venue, null: true, foreign_key: true

      t.string :title, null: false
      t.text :description

      # Stored in UTC (Rails default). Recurrences are expanded in
      # America/Denver so a 6pm class stays 6pm across DST.
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.boolean :all_day, null: false, default: false

      # RFC-5545 RRULE string, expanded server-side with ice_cube. Null means a
      # one-off event.
      t.string :recurrence_rule
      t.datetime :recurrence_until

      t.string :status, null: false, default: "scheduled"

      # `bookable: false` is an announcement. A column rather than "has blocks",
      # because "no blocks" and "not bookable" are otherwise indistinguishable
      # and she'd have no way to post a notice without it looking like an
      # oversight.
      t.boolean :bookable, null: false, default: false
      # Defaults inherited by the blocks generated from this event's
      # occurrences (Phase 7).
      t.integer :capacity
      t.string :price_note

      t.timestamps
    end

    add_index :events, :starts_at
    add_index :events, :status

    # An occurrence cannot end before it starts, whatever the app does.
    add_check_constraint :events, "ends_at > starts_at", name: "events_end_after_start"
    add_check_constraint :events, "capacity IS NULL OR capacity > 0", name: "events_capacity_positive"
    add_check_constraint :events, "status IN ('scheduled', 'cancelled')", name: "events_status_valid"
  end
end

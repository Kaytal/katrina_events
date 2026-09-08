# One deviation from a recurring event's rule: skip a single occurrence, or move
# it. `original_date` is the LOCAL date the rule would have produced, which is
# what identifies the occurrence — a UTC timestamp would shift across DST and
# stop matching.
class CreateEventExceptions < ActiveRecord::Migration[8.1]
  def change
    create_table :event_exceptions do |t|
      t.references :event, null: false, foreign_key: true
      t.date :original_date, null: false
      t.string :action, null: false

      # Only set when action is "move".
      t.datetime :starts_at
      t.datetime :ends_at

      t.timestamps
    end

    # One exception per occurrence: two rules for the same date is ambiguous.
    add_index :event_exceptions, [ :event_id, :original_date ], unique: true

    add_check_constraint :event_exceptions, "action IN ('skip', 'move')",
                         name: "event_exceptions_action_valid"
    # A move without a destination is meaningless; a skip with one is confusing.
    add_check_constraint :event_exceptions,
                         "(action = 'move' AND starts_at IS NOT NULL AND ends_at IS NOT NULL AND ends_at > starts_at)
                          OR (action = 'skip' AND starts_at IS NULL AND ends_at IS NULL)",
                         name: "event_exceptions_move_has_times"
  end
end

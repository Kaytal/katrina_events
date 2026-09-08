class CreateEventTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :event_types do |t|
      t.string :name, null: false
      t.string :slug, null: false
      # Drives the calendar's colour coding. Hex, validated in the model.
      t.string :color, null: false, default: "#6b3f7a"
      t.text :description

      t.timestamps
    end

    add_index :event_types, :slug, unique: true
  end
end

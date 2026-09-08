class CreateVenues < ActiveRecord::Migration[8.1]
  def change
    create_table :venues do |t|
      t.string :name, null: false
      t.string :address
      t.string :url
      t.text :notes

      t.timestamps
    end

    add_index :venues, :name, unique: true
  end
end

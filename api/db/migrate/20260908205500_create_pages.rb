class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages do |t|
      t.string :slug, null: false
      t.string :title, null: false
      t.text :body, null: false, default: ""
      t.string :meta_description
      # Null means draft. The public endpoint only serves rows where this is
      # set and in the past, so she can work on copy before it goes live.
      t.datetime :published_at

      t.timestamps
    end

    add_index :pages, :slug, unique: true
  end
end

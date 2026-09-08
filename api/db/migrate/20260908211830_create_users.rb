class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      # Devise :database_authenticatable
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      t.string :name, null: false
      t.string :role, null: false, default: "admin"

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end

# frozen_string_literal: true

module Types
  class UserType < Types::BaseObject
    description "An administrator. Only reachable through `me` and the login payload — never listed."

    field :id, ID, null: false
    field :email, String, null: false
    field :name, String, null: false
    field :role, String, null: false
  end
end

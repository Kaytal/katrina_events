# frozen_string_literal: true

module Types
  class AuthPayloadType < Types::BaseObject
    description "The result of a successful login."

    field :token, String, null: false,
          description: "JWT, valid 24 hours. Send as `Authorization: Bearer <token>`."
    field :user, Types::UserType, null: false
  end
end

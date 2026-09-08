# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :login, mutation: Mutations::Login
    field :logout, mutation: Mutations::Logout

    field :update_page, mutation: Mutations::UpdatePage
  end
end

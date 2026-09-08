# frozen_string_literal: true

module Mutations
  class Logout < BaseMutation
    description "Revoke the presented token. Logging out genuinely invalidates it, rather than only forgetting it on the client."

    field :success, Boolean, null: false

    def resolve
      require_admin!

      payload = context[:jwt_payload]
      # Defensive: current_user is only ever set from a decoded token, so a
      # signed-in request without a payload should be impossible.
      raise GraphQL::ExecutionError, "No token to revoke" if payload.blank?

      # Writes the jti to jwt_denylist, so the same token is rejected from here
      # on. Lives on the configured strategy, not on User.
      User.jwt_revocation_strategy.revoke_jwt(payload, current_user)

      { success: true }
    end
  end
end

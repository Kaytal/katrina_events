# frozen_string_literal: true

class ApiSchema < GraphQL::Schema
  query(Types::QueryType)

  # No mutation root yet. The first one is the Phase 3 login; shipping the
  # generator's `testField` placeholder just to have a root would put a dummy
  # field in a public schema.
  # mutation(Types::MutationType)

  use GraphQL::Dataloader

  # This endpoint is public and unauthenticated, so the cost of a query is set
  # by whoever sends it. Depth and complexity limits are the only thing between
  # a deeply nested query and a pegged Postgres.
  max_depth(10)
  max_complexity(200)
  max_query_string_tokens(5_000)
  default_max_page_size(100)

  validate_max_errors(100)

  # Deliberately no Relay node/nodes interface. The generator's version resolves
  # arbitrary global IDs through GlobalID.find, which bypasses every scope we
  # define — an unpublished page, and later a booking_request full of a child's
  # name and a parent's phone number, would be readable by anyone who can
  # construct the ID. Records are reachable only through fields that apply their
  # own visibility rules.

  # Errors we raise deliberately carry a machine-readable code; anything else is
  # logged and reported as a generic failure rather than leaking internals.
  rescue_from(ActiveRecord::RecordNotFound) do
    raise GraphQL::ExecutionError.new("Not found", extensions: { "code" => "NOT_FOUND" })
  end

  def self.unauthorized_object(error)
    raise GraphQL::ExecutionError.new(
      "Not authorized to access #{error.type.graphql_name}",
      extensions: { "code" => "FORBIDDEN" }
    )
  end

  def self.type_error(err, context)
    super
  end
end

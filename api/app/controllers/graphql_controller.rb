# frozen_string_literal: true

class GraphqlController < ApplicationController
  # Both verbs hit the same action. Queries arrive as GET so they keep HTTP
  # caching (see #apply_cache_headers); mutations must be POST, because a GET is
  # required to be safe and a cached mutation is a bug waiting to happen.
  def execute
    query = build_query

    return render_mutation_over_get if request.get? && mutation?(query)

    result = query.result
    apply_cache_headers(result)
    render json: result, status: response_status(result)
  rescue JSON::ParserError
    render json: error_payload("Variables must be valid JSON", "BAD_REQUEST"), status: :bad_request
  rescue StandardError => e
    raise e unless Rails.env.development?

    handle_error_in_development(e)
  end

  private

  def build_query
    GraphQL::Query.new(
      ApiSchema,
      params[:query],
      variables: prepare_variables(params[:variables]),
      operation_name: params[:operationName],
      context: query_context
    )
  end

  def query_context
    {
      # current_user arrives in Phase 3, from the devise-jwt Authorization header.
    }
  end

  # GraphQL-over-HTTP distinguishes two kinds of failure. A *request* error —
  # the document would not parse, or failed validation — produces a payload with
  # no `data` key at all, and is a 400: the request itself was never runnable.
  # A *field* error produces `data` (possibly null) alongside `errors`, and is a
  # 200, because the query ran and partially succeeded.
  def response_status(result)
    result.key?("data") || result["errors"].blank? ? :ok : :bad_request
  end

  def mutation?(query)
    query.selected_operation&.operation_type == "mutation"
  rescue GraphQL::ParseError
    # An unparseable document is not a mutation; let the normal path report it.
    false
  end

  def render_mutation_over_get
    render json: error_payload("Mutations must be sent as POST", "METHOD_NOT_ALLOWED"),
           status: :method_not_allowed
  end

  # Only a clean, unauthenticated GET is publicly cacheable. Anything else —
  # a mutation, a partial failure, or a request carrying credentials — must not
  # be stored, or one visitor's response can be served to another.
  def apply_cache_headers(result)
    if request.get? && result["errors"].blank? && !credentialed?
      expires_in 0, public: true, must_revalidate: true
    else
      response.cache_control.replace(no_store: true)
    end
  end

  def credentialed?
    request.headers["Authorization"].present?
  end

  def error_payload(message, code)
    { errors: [ { message: message, extensions: { "code" => code } } ], data: nil }
  end

  # Variables may arrive as a JSON string (GET query params), a parsed hash
  # (JSON body), or not at all.
  def prepare_variables(variables_param)
    case variables_param
    when String
      variables_param.present? ? (JSON.parse(variables_param) || {}) : {}
    when Hash
      variables_param
    when ActionController::Parameters
      variables_param.to_unsafe_hash # GraphQL-Ruby validates names and types.
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end

  def handle_error_in_development(exception)
    logger.error exception.message
    logger.error exception.backtrace.join("\n")

    render json: { errors: [ { message: exception.message, backtrace: exception.backtrace } ], data: nil },
           status: :internal_server_error
  end
end

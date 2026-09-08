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
    user, payload, auth_error = authenticate_from_token

    {
      current_user: user,
      jwt_payload: payload,
      # Lets require_admin! say "your session expired" rather than bouncing her
      # to the login form with no explanation.
      auth_error: auth_error
    }
  end

  # devise-jwt would normally do this in Warden middleware matched on a request
  # path. With one endpoint there is no path to match, so the token is decoded
  # here and the result handed to the schema through context.
  #
  # Returns [user, payload, error]. A bad token is not a request failure — `me`
  # answers null and the client clears it — so nothing raises.
  def authenticate_from_token
    token = bearer_token
    return [ nil, nil, nil ] if token.blank?

    payload = Warden::JWTAuth::TokenDecoder.new.call(token)
    user = User.find_for_jwt_authentication(payload["sub"])
    return [ nil, nil, :invalid ] if user.nil?

    # The decoder verifies the signature and expiry but knows nothing about
    # revocation, so logout would not actually log anyone out without this.
    # The check lives on the configured strategy (JwtDenylist), not on User.
    return [ nil, nil, :revoked ] if User.jwt_revocation_strategy.jwt_revoked?(payload, user)

    [ user, payload, nil ]
  rescue JWT::ExpiredSignature
    [ nil, nil, :expired ]
  rescue JWT::DecodeError
    [ nil, nil, :invalid ]
  end

  def bearer_token
    header = request.headers["Authorization"].to_s
    return nil unless header.start_with?("Bearer ")

    header.delete_prefix("Bearer ").strip.presence
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

    # Only the application frames, and only a handful. The full trace is in the
    # log; a 200-frame array in the response body just buries the message.
    app_frames = exception.backtrace.grep(%r{^/app/}).first(8)

    render json: {
      errors: [ { message: exception.message, exception: exception.class.name, backtrace: app_frames } ],
      data: nil
    }, status: :internal_server_error
  end
end

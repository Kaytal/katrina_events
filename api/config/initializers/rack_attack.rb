# Throttling for a single-endpoint API.
#
# The REST design threw a throttle in front of POST /api/v1/auth/login. With
# everything on /graphql, a path match cannot tell a page view from a login
# attempt, so the throttle has to key on the GraphQL *operation* instead. That
# means peeking at the request body here in middleware — before the body has
# been parsed, and taking care to rewind it so Rails can still read it.
class Rack::Attack
  # Operations that are cheap to send and expensive to get wrong. Matched
  # against the operation name and, as a fallback, the document text — a client
  # is not obliged to send operationName.
  THROTTLED_OPERATIONS = {
    "login" => { limit: 5, period: 20.minutes },
    "createBookingRequest" => { limit: 10, period: 1.hour },
    "createContactMessage" => { limit: 5, period: 1.hour }
  }.freeze

  MAX_INSPECTED_BODY_BYTES = 16_384

  class Request < ::Rack::Request
    INSPECTABLE_MEDIA_TYPES = %w[application/json application/x-www-form-urlencoded].freeze

    def graphql?
      path == "/graphql"
    end

    # The operation this request is trying to run, or nil. Prefers the explicit
    # operationName; falls back to spotting a throttled field in the document,
    # since operationName is optional and an attacker would simply omit it.
    def graphql_operation
      return @graphql_operation if defined?(@graphql_operation)

      @graphql_operation = graphql? ? detect_operation : nil
    end

    private

    def detect_operation
      name = param("operationName")
      return name if name.present? && THROTTLED_OPERATIONS.key?(name)

      document = param("query")
      return nil if document.blank?

      THROTTLED_OPERATIONS.keys.find { |operation| document.include?(operation) }
    end

    # Deliberately NOT Rack::Request#params or #POST. Those parse the request
    # body as form data, which reads `rack.input` — and Rack 3 dropped the
    # guarantee that it is rewindable, so touching them here leaves Rails
    # unable to parse the request at all. #GET reads only the query string,
    # which is safe; the body goes through buffered_body below.
    def param(key)
      value = self.GET[key].presence || buffered_body[key].presence
      value.is_a?(String) ? value.strip : value
    end

    def buffered_body
      return @buffered_body if defined?(@buffered_body)

      @buffered_body = parse_body
    end

    # Both media types Rails will accept for a GraphQL POST are inspected. If
    # only JSON were, an attacker could sidestep the login throttle entirely by
    # sending the same mutation form-encoded — which Rails accepts.
    def parse_body
      return {} unless post? && INSPECTABLE_MEDIA_TYPES.include?(media_type)

      # An oversized or chunked body is not inspected: it would have to be read
      # in full to be handed downstream intact, and the endpoint-wide throttle
      # still applies. Nothing is truncated, because a truncated body passed
      # downstream would break the request rather than throttle it.
      length = content_length.to_i
      return {} if length.zero? || length > MAX_INSPECTED_BODY_BYTES

      input = get_header(::Rack::RACK_INPUT)
      return {} if input.nil?

      raw = input.read.to_s
      # A fresh stream, not a rewind — see the comment on #param.
      set_header(::Rack::RACK_INPUT, StringIO.new(raw))

      decode(raw)
    rescue JSON::ParserError, EOFError
      # An unparseable body is the schema's problem to report, not ours.
      {}
    end

    def decode(raw)
      parsed =
        if media_type == "application/json"
          JSON.parse(raw)
        else
          ::Rack::Utils.parse_nested_query(raw)
        end

      parsed.is_a?(Hash) ? parsed : {}
    end
  end

  THROTTLED_OPERATIONS.each do |operation, options|
    throttle("graphql/#{operation}", limit: options[:limit], period: options[:period]) do |request|
      request.ip if request.graphql_operation == operation
    end
  end

  # A blunt ceiling on the endpoint as a whole, so an operation nobody thought
  # to enumerate above still cannot be hammered.
  throttle("graphql/all", limit: 300, period: 5.minutes) do |request|
    request.ip if request.graphql?
  end

  # Throttled responses are GraphQL-shaped: the client already knows how to
  # read errors[].extensions.code, and should not have to special-case a bare
  # 429 with an HTML body.
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    retry_after = (match_data[:period] || 60).to_i

    body = {
      errors: [ {
        message: "Too many attempts. Try again later.",
        extensions: { "code" => "TOO_MANY_REQUESTS" }
      } ],
      data: nil
    }.to_json

    [
      429,
      {
        "content-type" => "application/json",
        "retry-after" => retry_after.to_s,
        "cache-control" => "no-store"
      },
      [ body ]
    ]
  end
end

# Rack::Attack is enabled everywhere except test, where it would make specs
# order-dependent. The throttling specs switch it on explicitly.
Rack::Attack.enabled = !Rails.env.test?

# Counters live in the Rails cache. Development uses a memory store, which is
# per-process and therefore fine; production shares Solid Cache.
Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new if Rails.env.development?

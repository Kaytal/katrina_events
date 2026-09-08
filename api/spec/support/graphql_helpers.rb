# Executes a document straight against the schema, no HTTP. Use these for
# resolver behaviour; the specs in spec/requests/graphql_spec.rb cover the
# transport (verbs, status codes, cache headers) separately.
module GraphQLHelpers
  def execute_graphql(query, variables: {}, context: {})
    ApiSchema.execute(query, variables: variables, context: context).to_h
  end

  # Fetches a nested value out of a result, e.g. dig_data(result, "page", "title").
  def dig_data(result, *path)
    result.dig("data", *path)
  end

  def error_codes(result)
    Array(result["errors"]).map { |error| error.dig("extensions", "code") }
  end

  def error_messages(result)
    Array(result["errors"]).map { |error| error["message"] }
  end
end

RSpec.configure do |config|
  config.include GraphQLHelpers
end

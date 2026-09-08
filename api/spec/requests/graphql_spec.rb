require "rails_helper"

# Transport-level behaviour of the single /graphql endpoint. Resolver behaviour
# lives in spec/graphql.
RSpec.describe "/graphql" do
  let(:health_query) { "{ health { status } }" }

  describe "verbs" do
    it "accepts a query over GET" do
      get "/graphql", params: { query: health_query }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "health", "status")).to eq("ok")
    end

    it "accepts a query over POST" do
      post "/graphql", params: { query: health_query }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "health", "status")).to eq("ok")
    end

    it "refuses a mutation sent over GET, because a GET must be safe" do
      get "/graphql", params: { query: "mutation { whatever }" }

      expect(response).to have_http_status(:method_not_allowed)
      expect(response.parsed_body["errors"].first["extensions"]["code"])
        .to eq("METHOD_NOT_ALLOWED")
    end
  end

  describe "variables" do
    it "parses variables sent as a JSON string, as they arrive on a GET" do
      create(:page, slug: "about", title: "About Katrina")

      get "/graphql", params: {
        query: "query P($slug: String!) { page(slug: $slug) { title } }",
        variables: { slug: "about" }.to_json
      }

      expect(response.parsed_body.dig("data", "page", "title")).to eq("About Katrina")
    end

    it "rejects malformed variable JSON with a 400 rather than a 500" do
      get "/graphql", params: { query: health_query, variables: "{not json" }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["errors"].first["extensions"]["code"]).to eq("BAD_REQUEST")
    end

    it "rejects an unparseable document with a 400" do
      get "/graphql", params: { query: "{ health {" }

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "HTTP caching" do
    # Queries are sent as GET specifically so this keeps working; it is the one
    # property a move from REST to GraphQL most easily loses.
    it "makes a clean, anonymous query revalidatable rather than heuristically cacheable" do
      get "/graphql", params: { query: health_query }

      cache_control = response.headers["Cache-Control"]
      expect(cache_control).to include("max-age=0")
      expect(cache_control).to include("must-revalidate")
      expect(response.headers["ETag"]).to be_present
    end

    it "answers 304 when the client revalidates an unchanged query" do
      create(:page, slug: "about")
      query = { query: "{ page(slug: \"about\") { title } }" }

      get "/graphql", params: query
      etag = response.headers["ETag"]

      get "/graphql", params: query, headers: { "If-None-Match" => etag }

      expect(response).to have_http_status(:not_modified)
    end

    it "never stores a response to a request carrying credentials" do
      get "/graphql", params: { query: health_query },
                      headers: { "Authorization" => "Bearer whatever" }

      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "never stores a response that carried errors" do
      get "/graphql", params: { query: "{ page(slug: \"nope\") { title } }" }

      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "never stores the response to a mutation" do
      post "/graphql", params: { query: health_query }

      expect(response.headers["Cache-Control"]).to include("no-store")
    end
  end

  describe "query cost limits" do
    # The endpoint is public and unauthenticated, so whoever sends the query
    # decides how expensive it is unless the schema says otherwise.
    it "rejects a query nested past max_depth" do
      # Introspection is the realistic way to nest deeply against a small
      # schema, and the realistic shape of a depth attack.
      nested = "ofType { " * 9
      deep = "{ __schema { types { fields { type { #{nested} name #{'}' * 9} } } } } }"

      get "/graphql", params: { query: deep }

      expect(error_messages(response.parsed_body).join).to match(/exceeds max depth/i)
    end
  end

  describe "the Relay node field" do
    it "is not in the schema, so records cannot be fetched by global ID" do
      get "/graphql", params: { query: "{ node(id: \"x\") { __typename } }" }

      expect(response.parsed_body["errors"].first["message"]).to match(/doesn't exist on type 'Query'/)
    end
  end
end

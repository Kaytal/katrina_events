require "rails_helper"

# Rack::Attack is disabled in test by default (it would make specs
# order-dependent), so these switch it on and reset the counters themselves.
RSpec.describe "Throttling /graphql" do
  around do |example|
    original_store = Rack::Attack.cache.store
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.enabled = true

    example.run
  ensure
    Rack::Attack.enabled = false
    Rack::Attack.cache.store = original_store
  end

  let(:login_document) do
    "mutation Login($e: String!, $p: String!) { login(input: { email: $e, password: $p }) { token } }"
  end

  def attempt_login(as_json: true, operation_name: "Login")
    payload = {
      query: login_document,
      variables: { e: "katrina@example.invalid", p: "wrong" },
      operationName: operation_name
    }

    if as_json
      post "/graphql", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    else
      post "/graphql", params: payload.merge(variables: payload[:variables].to_json)
    end
  end

  it "blocks repeated login attempts from one IP" do
    5.times { attempt_login }

    expect(response).to have_http_status(:ok)

    attempt_login

    expect(response).to have_http_status(:too_many_requests)
    expect(response.parsed_body["errors"].first["extensions"]["code"]).to eq("TOO_MANY_REQUESTS")
    expect(response.headers["retry-after"]).to be_present
  end

  # An attacker will not helpfully label the request, so the throttle falls back
  # to spotting the field in the document.
  it "still throttles when operationName is omitted" do
    5.times { attempt_login(operation_name: nil) }
    attempt_login(operation_name: nil)

    expect(response).to have_http_status(:too_many_requests)
  end

  # Rails accepts a form-encoded GraphQL POST, so inspecting only JSON would
  # leave a trivial bypass.
  it "still throttles a form-encoded login" do
    5.times { attempt_login(as_json: false) }
    attempt_login(as_json: false)

    expect(response).to have_http_status(:too_many_requests)
  end

  it "leaves ordinary page traffic alone" do
    create(:page, slug: "home")

    10.times { get "/graphql", params: { query: '{ page(slug: "home") { title } }' } }

    expect(response).to have_http_status(:ok)
  end

  # Reading the body to find the operation must not stop Rails from reading it
  # too: Rack 3 does not guarantee rack.input is rewindable.
  it "leaves the request body intact for Rails to parse" do
    create(:page, slug: "home")

    post "/graphql", params: { query: '{ page(slug: "home") { title } }' }.to_json,
                     headers: { "CONTENT_TYPE" => "application/json" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "page", "title")).to be_present
  end

  it "does not throttle a normal successful login" do
    user = create(:user)

    post "/graphql", params: {
      query: login_document,
      variables: { e: user.email, p: "correct-horse-battery-staple" }
    }.to_json, headers: { "CONTENT_TYPE" => "application/json" }

    expect(response.parsed_body.dig("data", "login", "token")).to be_present
  end
end

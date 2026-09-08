require "rails_helper"

# The token's journey through the real stack: header parsing, signature and
# expiry verification, the denylist check, and the codes the client branches on.
RSpec.describe "Authentication over /graphql" do
  let(:me_query) { { query: "{ me { email } }" } }
  let(:logout_query) { { query: "mutation { logout(input: {}) { success } }" } }
  let(:user) { create(:user, email: "katrina@example.invalid") }

  describe "the me query" do
    it "is null without a token, so the client can boot without an error" do
      post "/graphql", params: me_query

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to eq("me" => nil)
      expect(response.parsed_body["errors"]).to be_nil
    end

    it "returns the signed-in administrator with a valid token" do
      post "/graphql", params: me_query, headers: auth_headers(user)

      expect(response.parsed_body.dig("data", "me", "email")).to eq("katrina@example.invalid")
    end
  end

  describe "token handling" do
    it "ignores a token that is not a Bearer credential" do
      post "/graphql", params: me_query, headers: { "Authorization" => issue_token(user) }

      expect(response.parsed_body["data"]).to eq("me" => nil)
    end

    it "rejects a token signed with the wrong secret" do
      forged = JWT.encode({ sub: user.id.to_s, jti: SecureRandom.uuid, exp: 1.hour.from_now.to_i },
                          "not-the-real-secret", "HS256")

      post "/graphql", params: logout_query, headers: auth_headers(forged)

      expect(response.parsed_body["errors"].first["extensions"]["code"]).to eq("UNAUTHENTICATED")
    end

    it "rejects a token whose user no longer exists" do
      token = issue_token(user)
      user.destroy!

      post "/graphql", params: me_query, headers: auth_headers(token)

      expect(response.parsed_body["data"]).to eq("me" => nil)
    end

    it "reports an expired token distinctly, so she is told her session ended" do
      token = issue_token(user)

      travel 25.hours do
        post "/graphql", params: logout_query, headers: auth_headers(token)
      end

      error = response.parsed_body["errors"].first
      expect(error["extensions"]["code"]).to eq("TOKEN_EXPIRED")
      expect(error["message"]).to match(/expired/i)
    end
  end

  describe "logout, end to end" do
    it "makes the same token unusable afterwards" do
      token = issue_token(user)

      post "/graphql", params: logout_query, headers: auth_headers(token)
      expect(response.parsed_body.dig("data", "logout", "success")).to be(true)

      post "/graphql", params: me_query, headers: auth_headers(token)
      expect(response.parsed_body["data"]).to eq("me" => nil)

      post "/graphql", params: logout_query, headers: auth_headers(token)
      expect(response.parsed_body["errors"].first["extensions"]["code"]).to eq("TOKEN_REVOKED")
    end

    it "leaves a token issued after logout working" do
      old_token = issue_token(user)
      post "/graphql", params: logout_query, headers: auth_headers(old_token)

      fresh_token = issue_token(user)
      post "/graphql", params: me_query, headers: auth_headers(fresh_token)

      expect(response.parsed_body.dig("data", "me", "email")).to eq("katrina@example.invalid")
    end
  end

  describe "caching" do
    # A cacheable authenticated response is one visitor's data served to
    # another. Belt-and-braces alongside the Phase 2 specs.
    it "never stores a response to an authenticated request" do
      post "/graphql", params: me_query, headers: auth_headers(user)

      expect(response.headers["Cache-Control"]).to include("no-store")
    end

    it "never stores a login response, which contains a token" do
      post "/graphql", params: {
        query: "mutation L($e: String!, $p: String!) { login(input: { email: $e, password: $p }) { token } }",
        variables: { e: user.email, p: "correct-horse-battery-staple" }.to_json
      }

      expect(response.headers["Cache-Control"]).to include("no-store")
    end
  end
end

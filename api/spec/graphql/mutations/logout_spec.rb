require "rails_helper"

RSpec.describe Mutations::Logout do
  let(:query) { "mutation { logout(input: {}) { success } }" }

  it "revokes the presented token" do
    user = create(:user)

    result = execute_as(user, query)

    expect(dig_data(result, "logout", "success")).to be(true)
    expect(JwtDenylist.count).to eq(1)
  end

  it "denylists the token's own jti, not some other token's" do
    user = create(:user)
    payload = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).last

    execute_graphql(query, context: { current_user: user, jwt_payload: payload })

    expect(JwtDenylist.first.jti).to eq(payload["jti"])
  end

  it "is idempotent, so a double click does not raise" do
    user = create(:user)
    payload = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).last
    context = { current_user: user, jwt_payload: payload }

    execute_graphql(query, context: context)
    result = execute_graphql(query, context: context)

    expect(dig_data(result, "logout", "success")).to be(true)
    expect(JwtDenylist.count).to eq(1)
  end

  it "refuses an unauthenticated request" do
    result = execute_graphql(query)

    expect(error_codes(result)).to eq([ "UNAUTHENTICATED" ])
    expect(JwtDenylist.count).to be_zero
  end
end

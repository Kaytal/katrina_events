require "rails_helper"

RSpec.describe Mutations::Login do
  let(:query) do
    <<~GRAPHQL
      mutation Login($email: String!, $password: String!) {
        login(input: { email: $email, password: $password }) {
          token
          user { email name role }
        }
      }
    GRAPHQL
  end

  def login(email:, password:)
    execute_graphql(query, variables: { "email" => email, "password" => password })
  end

  it "returns a usable token and the user" do
    create(:user, email: "katrina@example.invalid", password: "a-good-password", name: "Katrina")

    result = login(email: "katrina@example.invalid", password: "a-good-password")

    expect(result["errors"]).to be_nil
    expect(dig_data(result, "login", "user")).to include("email" => "katrina@example.invalid")

    token = dig_data(result, "login", "token")
    payload = Warden::JWTAuth::TokenDecoder.new.call(token)
    expect(payload["sub"]).to eq(User.last.id.to_s)
    expect(payload["jti"]).to be_present
  end

  it "issues a token that expires in 24 hours" do
    user = create(:user)

    token = dig_data(login(email: user.email, password: "correct-horse-battery-staple"), "login", "token")
    payload = Warden::JWTAuth::TokenDecoder.new.call(token)

    expect(Time.at(payload["exp"])).to be_within(1.minute).of(24.hours.from_now)
  end

  it "matches the email case-insensitively" do
    create(:user, email: "katrina@example.invalid", password: "a-good-password")

    result = login(email: "  KATRINA@example.INVALID  ", password: "a-good-password")

    expect(dig_data(result, "login", "token")).to be_present
  end

  it "rejects a wrong password" do
    create(:user, email: "katrina@example.invalid", password: "a-good-password")

    result = login(email: "katrina@example.invalid", password: "nope")

    expect(dig_data(result, "login")).to be_nil
    expect(error_codes(result)).to eq([ "INVALID_CREDENTIALS" ])
  end

  # Distinguishing "no such account" from "wrong password" turns the login form
  # into an account enumerator.
  it "gives an identical response for an unknown email and a wrong password" do
    create(:user, email: "katrina@example.invalid", password: "a-good-password")

    wrong_password = login(email: "katrina@example.invalid", password: "nope")
    unknown_email = login(email: "stranger@example.invalid", password: "nope")

    expect(error_messages(unknown_email)).to eq(error_messages(wrong_password))
    expect(error_codes(unknown_email)).to eq(error_codes(wrong_password))
  end

  it "never puts the password or the hash in the response" do
    user = create(:user, password: "a-good-password")

    result = login(email: user.email, password: "a-good-password")

    expect(result.to_json).not_to include("a-good-password")
    expect(result.to_json).not_to include(user.encrypted_password)
  end
end

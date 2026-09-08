# Tokens are minted the same way the login mutation mints them, so specs
# exercise the real encoder rather than a hand-rolled JWT that could drift from
# what the app actually issues.
module AuthHelpers
  def issue_token(user)
    token, _payload = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
    token
  end

  def auth_headers(user_or_token)
    token = user_or_token.is_a?(User) ? issue_token(user_or_token) : user_or_token
    { "Authorization" => "Bearer #{token}" }
  end

  # Executes a document with the context the controller would have built.
  def execute_as(user, query, variables: {})
    payload = user && Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).last

    execute_graphql(query, variables: variables,
                           context: { current_user: user, jwt_payload: payload })
  end
end

RSpec.configure do |config|
  config.include AuthHelpers
end

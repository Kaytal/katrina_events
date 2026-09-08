# frozen_string_literal: true

module Mutations
  class Login < BaseMutation
    description "Exchange an email and password for a 24-hour JWT."

    argument :email, String, required: true
    argument :password, String, required: true

    field :token, String, null: false
    field :user, Types::UserType, null: false

    def resolve(email:, password:)
      user = User.find_by(email: email.to_s.strip.downcase)

      # One message and one code for both "no such user" and "wrong password".
      # Distinguishing them turns the login form into an account enumerator.
      unless user&.valid_password?(password)
        raise GraphQL::ExecutionError.new(
          "Invalid email or password",
          extensions: { "code" => "INVALID_CREDENTIALS" }
        )
      end

      { token: issue_token(user), user: user }
    end

    private

    # devise-jwt normally issues tokens from Warden middleware matched on a
    # request path. There are no Devise routes here, so we call its encoder
    # directly — same secret, same expiry, same jti recorded for revocation.
    def issue_token(user)
      token, _payload = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil)
      token
    end
  end
end

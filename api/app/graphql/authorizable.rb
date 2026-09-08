# Shared by QueryType and every mutation. Authorization is explicit at each
# field rather than a blanket before_action: with one endpoint there is no path
# to protect, so a field that forgets to ask is a field that is public.
module Authorizable
  private

  def current_user
    context[:current_user]
  end

  def signed_in?
    current_user.present?
  end

  # Raises rather than returning nil, so a caller cannot accidentally continue
  # with a null user.
  def require_admin!
    unless signed_in?
      raise GraphQL::ExecutionError.new(
        unauthenticated_message,
        extensions: { "code" => unauthenticated_code }
      )
    end

    unless current_user.admin?
      raise GraphQL::ExecutionError.new(
        "Not permitted",
        extensions: { "code" => "FORBIDDEN" }
      )
    end

    current_user
  end

  # An expired or revoked token is a different situation from never having
  # signed in, and the client shows different copy for each.
  def unauthenticated_code
    case context[:auth_error]
    when :expired then "TOKEN_EXPIRED"
    when :revoked then "TOKEN_REVOKED"
    else "UNAUTHENTICATED"
    end
  end

  def unauthenticated_message
    case context[:auth_error]
    when :expired then "Your session expired. Please sign in again."
    when :revoked then "You are signed out. Please sign in again."
    else "You must be signed in"
    end
  end
end

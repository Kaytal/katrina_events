# Katrina, and optionally Josh. Created by seed, never by signup: `registerable`
# is deliberately absent, so there is no public account-creation surface at all.
class User < ApplicationRecord
  ROLES = %w[admin].freeze

  devise :database_authenticatable, :validatable, :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist

  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: ROLES }

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  def admin?
    role == "admin"
  end
end

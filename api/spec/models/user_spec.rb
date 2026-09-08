require "rails_helper"

RSpec.describe User do
  it "requires a name and a valid role" do
    user = described_class.new(email: "a@b.invalid", password: "password123")

    expect(user).not_to be_valid
    expect(user.errors[:name]).to be_present
  end

  it "rejects a role outside the allowed set" do
    expect(build(:user, role: "superuser")).not_to be_valid
  end

  it "downcases and strips the email" do
    expect(described_class.new(email: "  Katrina@Example.INVALID ").email)
      .to eq("katrina@example.invalid")
  end

  it "rejects a duplicate email" do
    create(:user, email: "katrina@example.invalid")

    expect(build(:user, email: "katrina@example.invalid")).not_to be_valid
  end

  it "stores the password hashed, never in the clear" do
    user = create(:user, password: "correct-horse-battery-staple")

    expect(user.encrypted_password).not_to include("correct-horse")
    expect(user.valid_password?("correct-horse-battery-staple")).to be(true)
    expect(user.valid_password?("wrong")).to be(false)
  end

  # registerable is deliberately omitted, so there is no signup surface at all.
  it "does not include Devise's registerable module" do
    expect(described_class.devise_modules).not_to include(:registerable)
  end

  it "uses the denylist revocation strategy, so logout can invalidate a token" do
    expect(described_class.jwt_revocation_strategy).to eq(JwtDenylist)
  end
end

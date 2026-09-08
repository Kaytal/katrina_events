FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "admin#{n}@example.invalid" }
    name { "Katrina" }
    role { "admin" }
    password { "correct-horse-battery-staple" }
  end
end

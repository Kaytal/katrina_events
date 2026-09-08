FactoryBot.define do
  factory :venue do
    sequence(:name) { |n| "Venue #{n}" }
    address { "123 Example St, Denver, CO" }
  end
end

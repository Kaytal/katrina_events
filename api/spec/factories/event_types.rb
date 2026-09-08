FactoryBot.define do
  factory :event_type do
    sequence(:name) { |n| "Type #{n}" }
    sequence(:slug) { |n| "type-#{n}" }
    color { "#6b3f7a" }
  end
end

FactoryBot.define do
  factory :event_exception do
    event
    original_date { Date.new(2026, 4, 14) }
    action { "skip" }

    trait :move do
      action { "move" }
      starts_at { Time.zone.parse("2026-04-15 18:00") }
      ends_at { Time.zone.parse("2026-04-15 19:00") }
    end
  end
end

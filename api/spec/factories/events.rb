FactoryBot.define do
  factory :event do
    event_type
    title { "An event" }
    # 6pm–7pm Mountain, the shape of a real class.
    starts_at { Time.zone.parse("2026-04-07 18:00") }
    ends_at { Time.zone.parse("2026-04-07 19:00") }
    status { "scheduled" }
    bookable { false }

    trait :weekly do
      recurrence_rule { "FREQ=WEEKLY;BYDAY=TU" }
    end

    trait :bookable do
      bookable { true }
      capacity { 12 }
      price_note { "$15 per class, Venmo" }
    end

    trait :cancelled do
      status { "cancelled" }
    end
  end
end

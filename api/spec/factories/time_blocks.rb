FactoryBot.define do
  factory :time_block do
    event_type
    starts_at { Time.zone.parse("2026-04-07 16:00") }
    ends_at { Time.zone.parse("2026-04-07 16:30") }
    status { "open" }
  end
end

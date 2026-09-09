FactoryBot.define do
  factory :availability_pattern do
    event_type
    weekday { 2 } # Tuesday
    start_time { "16:00" }
    end_time { "18:00" }
    slot_minutes { 30 }
    capacity { 1 }
    effective_from { Date.new(2026, 4, 1) }
    active { true }
  end
end

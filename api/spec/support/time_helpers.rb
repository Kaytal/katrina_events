# `travel` / `freeze_time` are used by the token-expiry specs and, in Phase 5,
# by the DST-boundary recurrence specs.
RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
end

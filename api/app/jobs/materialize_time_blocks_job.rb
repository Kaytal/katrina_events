# Keeps a rolling window of concrete blocks populated. Runs nightly, and again
# on demand whenever she saves an event or a pattern — waiting until 2am to see
# the slots you just configured would make the editor feel broken.
class MaterializeTimeBlocksJob < ApplicationJob
  queue_as :default

  def perform(window_days: TimeBlocks::Materializer::DEFAULT_WINDOW.in_days.to_i)
    result = TimeBlocks::Materializer.call(
      from: Time.current.beginning_of_day,
      to: Time.current.beginning_of_day + window_days.days
    )

    Rails.logger.info("MaterializeTimeBlocksJob: #{result}")
    result
  end
end

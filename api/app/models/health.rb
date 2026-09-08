# Not an Active Record model — a value object behind the `health` query, so the
# database probe lives somewhere testable rather than inside a resolver.
class Health
  SERVICE_NAME = "katrina-events-api"

  def status
    database == "connected" ? "ok" : "degraded"
  end

  def service
    SERVICE_NAME
  end

  def environment
    Rails.env.to_s
  end

  def time
    Time.current
  end

  def time_zone
    Time.zone.name
  end

  # Memoized: the field may be selected once but is cheap to ask for twice.
  def database
    @database ||= probe_database
  end

  private

  def probe_database
    ActiveRecord::Base.connection.execute("SELECT 1")
    "connected"
  rescue ActiveRecord::ActiveRecordError, PG::Error => e
    Rails.logger.error("Health check database probe failed: #{e.class}: #{e.message}")
    "unavailable"
  end
end

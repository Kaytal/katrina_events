module Api
  module V1
    # Liveness plus a real database round-trip, so a green response means the
    # whole path — nginx or esbuild, Puma, Active Record, Postgres — is up.
    class HealthController < ApplicationController
      def show
        render json: {
          status: "ok",
          service: "katrina-events-api",
          environment: Rails.env,
          time: Time.current.iso8601,
          time_zone: Time.zone.name,
          database: database_status
        }
      end

      private

      def database_status
        ActiveRecord::Base.connection.execute("SELECT 1")
        "connected"
      rescue ActiveRecord::ActiveRecordError, PG::Error => e
        Rails.logger.error("Health check database probe failed: #{e.class}: #{e.message}")
        "unavailable"
      end
    end
  end
end

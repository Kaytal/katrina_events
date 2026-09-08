# Development only. esbuild serves the frontend from :3001 while Rails answers
# on :3000, which is cross-origin; in production nginx fronts both on a single
# origin, so no CORS headers are sent and no preflight is paid for.
if Rails.env.development?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins ENV.fetch("CORS_ORIGINS", "http://localhost:3001").split(",").map(&:strip)
      resource "/api/*", headers: :any, methods: %i[get post patch put delete options head]
    end
  end
end

require "rails_helper"

RSpec.describe "GET /api/v1/health" do
  it "reports the service, environment, and configured time zone" do
    get "/api/v1/health"

    expect(response).to have_http_status(:ok)

    body = response.parsed_body
    expect(body["status"]).to eq("ok")
    expect(body["service"]).to eq("katrina-events-api")
    expect(body["environment"]).to eq("test")
    expect(body["time_zone"]).to eq("America/Denver")
  end

  it "confirms the database round-trip" do
    get "/api/v1/health"

    expect(response.parsed_body["database"]).to eq("connected")
  end

  it "reports the database unavailable rather than raising when the probe fails" do
    allow(ActiveRecord::Base.connection)
      .to receive(:execute)
      .with("SELECT 1")
      .and_raise(ActiveRecord::ConnectionNotEstablished)

    get "/api/v1/health"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["database"]).to eq("unavailable")
  end
end

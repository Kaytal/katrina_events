require "rails_helper"

RSpec.describe "Query.events" do
  let(:query) do
    <<~GRAPHQL
      query Events($from: ISO8601DateTime!, $to: ISO8601DateTime!) {
        events(from: $from, to: $to) {
          id
          eventId
          title
          startsAt
          endsAt
          allDay
          bookable
          capacity
          priceNote
          recurring
          moved
          originalDate
          eventType { name slug color }
          venue { name address }
        }
      }
    GRAPHQL
  end

  def events(from:, to:)
    result = execute_graphql(query, variables: { "from" => from, "to" => to })
    raise result["errors"].inspect if result["errors"] && result["errors"].any? { |e| e["path"].nil? }

    result
  end

  let(:venue) { create(:venue, name: "Uplift") }
  let(:event_type) { create(:event_type, name: "Littles Dance Class", slug: "littles", color: "#6b3f7a") }

  it "returns expanded occurrences, not recurrence rules" do
    create(:event, :weekly, :bookable,
           event_type: event_type, venue: venue, title: "Littles Dance Class",
           starts_at: Time.zone.parse("2026-04-07 16:30"),
           ends_at: Time.zone.parse("2026-04-07 17:15"))

    result = events(from: "2026-04-01T00:00:00-06:00", to: "2026-05-01T00:00:00-06:00")
    occurrences = dig_data(result, "events")

    expect(occurrences.size).to eq(4)
    expect(occurrences.map { |o| o["startsAt"] }).to all(include("16:30"))
    expect(result.to_json).not_to include("FREQ=WEEKLY")
  end

  it "includes everything the calendar needs, so it needs no second call" do
    create(:event, :weekly, :bookable,
           event_type: event_type, venue: venue, title: "Littles Dance Class",
           starts_at: Time.zone.parse("2026-04-07 16:30"),
           ends_at: Time.zone.parse("2026-04-07 17:15"))

    occurrence = dig_data(events(from: "2026-04-01T00:00:00-06:00", to: "2026-04-10T00:00:00-06:00"), "events").first

    expect(occurrence).to include(
      "title" => "Littles Dance Class",
      "bookable" => true,
      "capacity" => 12,
      "recurring" => true,
      "moved" => false,
      "originalDate" => "2026-04-07"
    )
    expect(occurrence["eventType"]).to include("color" => "#6b3f7a")
    expect(occurrence["venue"]).to include("name" => "Uplift")
  end

  it "marks an announcement as not bookable" do
    create(:event, event_type: event_type, title: "Festival main stage",
                   starts_at: Time.zone.parse("2026-04-11 14:00"),
                   ends_at: Time.zone.parse("2026-04-11 15:00"))

    occurrence = dig_data(events(from: "2026-04-01T00:00:00-06:00", to: "2026-05-01T00:00:00-06:00"), "events").first

    expect(occurrence).to include("bookable" => false, "capacity" => nil, "recurring" => false)
  end

  it "omits a venue-less event's venue rather than failing" do
    create(:event, event_type: event_type, venue: nil,
                   starts_at: Time.zone.parse("2026-04-11 14:00"),
                   ends_at: Time.zone.parse("2026-04-11 15:00"))

    expect(dig_data(events(from: "2026-04-01T00:00:00-06:00", to: "2026-05-01T00:00:00-06:00"), "events").first["venue"])
      .to be_nil
  end

  it "flags a moved occurrence and keeps its original date as identity" do
    event = create(:event, :weekly, event_type: event_type,
                                    starts_at: Time.zone.parse("2026-04-07 16:30"),
                                    ends_at: Time.zone.parse("2026-04-07 17:15"))
    create(:event_exception, :move, event: event,
                                    original_date: Date.new(2026, 4, 14),
                                    starts_at: Time.zone.parse("2026-04-15 16:30"),
                                    ends_at: Time.zone.parse("2026-04-15 17:15"))

    moved = dig_data(events(from: "2026-04-01T00:00:00-06:00", to: "2026-05-01T00:00:00-06:00"), "events")
            .find { |o| o["moved"] }

    expect(moved["originalDate"]).to eq("2026-04-14")
    expect(moved["startsAt"]).to include("2026-04-15")
  end

  it "sends ISO-8601 with the Mountain offset, so the client never guesses a zone" do
    create(:event, event_type: event_type,
                   starts_at: Time.zone.parse("2026-04-11 14:00"),
                   ends_at: Time.zone.parse("2026-04-11 15:00"))

    starts_at = dig_data(events(from: "2026-04-01T00:00:00-06:00", to: "2026-05-01T00:00:00-06:00"), "events")
                .first["startsAt"]

    expect(starts_at).to eq("2026-04-11T14:00:00-06:00")
  end

  it "is public: no token required" do
    create(:event, event_type: event_type,
                   starts_at: Time.zone.parse("2026-04-11 14:00"),
                   ends_at: Time.zone.parse("2026-04-11 15:00"))

    result = events(from: "2026-04-01T00:00:00-06:00", to: "2026-05-01T00:00:00-06:00")

    expect(result["errors"]).to be_nil
    expect(dig_data(result, "events").size).to eq(1)
  end

  describe "guardrails" do
    it "refuses a range wide enough to be a denial of service" do
      result = execute_graphql(query, variables: {
                                 "from" => "2026-01-01T00:00:00Z", "to" => "2030-01-01T00:00:00Z"
                               })

      expect(error_codes(result)).to eq([ "RANGE_TOO_LARGE" ])
    end

    it "refuses a backwards range" do
      result = execute_graphql(query, variables: {
                                 "from" => "2026-05-01T00:00:00Z", "to" => "2026-04-01T00:00:00Z"
                               })

      expect(error_codes(result)).to eq([ "BAD_REQUEST" ])
    end
  end
end

RSpec.describe "Query.eventTypes" do
  it "returns every category alphabetically, for the calendar legend" do
    create(:event_type, name: "Workshop", slug: "workshop")
    create(:event_type, name: "Littles Dance Class", slug: "littles")

    result = execute_graphql("{ eventTypes { name slug color } }")

    expect(dig_data(result, "eventTypes").map { |type| type["name"] })
      .to eq([ "Littles Dance Class", "Workshop" ])
  end
end

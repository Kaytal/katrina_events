require "rails_helper"

RSpec.describe "Admin.events" do
  let(:user) { create(:user) }

  it "returns stored events, one row per event rather than per occurrence" do
    create(:event, :weekly, title: "Littles Dance Class")

    result = execute_as(user, "{ admin { events { id title recurrenceRule recurring } } }")
    events = dig_data(result, "admin", "events")

    expect(events.size).to eq(1)
    expect(events.first).to include("recurrenceRule" => "FREQ=WEEKLY;BYDAY=TU", "recurring" => true)
  end

  it "includes cancelled events, which the public calendar hides" do
    create(:event, :cancelled, title: "Called off")

    result = execute_as(user, "{ admin { events { title status } } }")

    expect(dig_data(result, "admin", "events").first).to include("status" => "cancelled")
  end

  it "can exclude cancelled events on request" do
    create(:event, :cancelled, title: "Called off")
    create(:event, title: "Still on")

    result = execute_as(user, "{ admin { events(includeCancelled: false) { title } } }")

    expect(dig_data(result, "admin", "events").map { |e| e["title"] }).to eq([ "Still on" ])
  end

  it "exposes the recurrence rule, which the public schema never does" do
    create(:event, :weekly)

    public_result = execute_graphql(
      'query { events(from: "2026-04-01T00:00:00-06:00", to: "2026-05-01T00:00:00-06:00") { title } }'
    )

    expect(public_result.to_json).not_to include("FREQ=")
  end

  describe "occurrences on one event" do
    let!(:event) do
      create(:event, :weekly,
             starts_at: Time.zone.parse("2026-04-07 18:00"),
             ends_at: Time.zone.parse("2026-04-07 19:00"))
    end

    let(:query) do
      <<~GRAPHQL
        query One($id: ID!, $from: ISO8601DateTime!, $to: ISO8601DateTime!) {
          admin {
            event(id: $id) {
              title
              exceptions { originalDate action }
              occurrences(from: $from, to: $to) {
                originalDate startsAt skipped moved
              }
            }
          }
        }
      GRAPHQL
    end

    def occurrences
      result = execute_as(user, query, variables: {
                            "id" => event.id.to_s,
                            "from" => "2026-04-01T00:00:00-06:00",
                            "to" => "2026-05-01T00:00:00-06:00"
                          })
      dig_data(result, "admin", "event", "occurrences")
    end

    it "lists what the rule produces, so she has something to cancel or move" do
      expect(occurrences.map { |o| o["originalDate"] })
        .to eq(%w[2026-04-07 2026-04-14 2026-04-21 2026-04-28])
    end

    it "keeps a cancelled occurrence in the list, flagged" do
      create(:event_exception, event: event, original_date: Date.new(2026, 4, 14), action: "skip")

      cancelled = occurrences.find { |o| o["originalDate"] == "2026-04-14" }

      expect(cancelled).to include("skipped" => true, "moved" => false)
    end

    it "reports a moved occurrence at its new time" do
      create(:event_exception, :move, event: event,
                                      original_date: Date.new(2026, 4, 14),
                                      starts_at: Time.zone.parse("2026-04-16 17:00"),
                                      ends_at: Time.zone.parse("2026-04-16 18:00"))

      moved = occurrences.find { |o| o["originalDate"] == "2026-04-14" }

      expect(moved).to include("moved" => true, "skipped" => false)
      expect(moved["startsAt"]).to include("2026-04-16T17:00")
    end

    it "lists the exceptions alongside, oldest first" do
      create(:event_exception, event: event, original_date: Date.new(2026, 4, 21), action: "skip")
      create(:event_exception, event: event, original_date: Date.new(2026, 4, 14), action: "skip")

      result = execute_as(user, query, variables: {
                            "id" => event.id.to_s,
                            "from" => "2026-04-01T00:00:00-06:00",
                            "to" => "2026-05-01T00:00:00-06:00"
                          })

      expect(dig_data(result, "admin", "event", "exceptions").map { |e| e["originalDate"] })
        .to eq(%w[2026-04-14 2026-04-21])
    end
  end

  it "never shows a skipped occurrence on the public calendar" do
    event = create(:event, :weekly,
                   starts_at: Time.zone.parse("2026-04-07 18:00"),
                   ends_at: Time.zone.parse("2026-04-07 19:00"))
    create(:event_exception, event: event, original_date: Date.new(2026, 4, 14), action: "skip")

    result = execute_graphql(
      'query { events(from: "2026-04-01T00:00:00-06:00", to: "2026-05-01T00:00:00-06:00") ' \
      "{ originalDate skipped } }"
    )

    expect(dig_data(result, "events").map { |o| o["originalDate"] }).not_to include("2026-04-14")
    expect(dig_data(result, "events")).to all(include("skipped" => false))
  end

  describe "the gate" do
    it "refuses admin.events without a token" do
      create(:event, :weekly, title: "Littles Dance Class")

      result = execute_graphql("{ admin { events { title recurrenceRule } } }")

      expect(error_codes(result)).to eq([ "UNAUTHENTICATED" ])
      expect(result.to_json).not_to include("FREQ=")
    end
  end
end

RSpec.describe "Venue CRUD" do
  let(:user) { create(:user) }

  it "creates a venue so a new festival can be announced" do
    query = <<~GRAPHQL
      mutation { createVenue(input: { name: "Larkspur Fairgrounds", address: "Larkspur, CO" }) {
        venue { name address } errors { field messages } } }
    GRAPHQL

    result = execute_as(user, query)

    expect(dig_data(result, "createVenue", "venue")).to include("name" => "Larkspur Fairgrounds")
  end

  it "rejects a malformed URL rather than storing it" do
    query = <<~GRAPHQL
      mutation { createVenue(input: { name: "Somewhere", url: "example.invalid" }) {
        venue { name } errors { field messages } } }
    GRAPHQL

    result = execute_as(user, query)

    expect(dig_data(result, "createVenue", "venue")).to be_nil
    expect(dig_data(result, "createVenue", "errors").first).to include("field" => "url")
  end

  it "refuses an unauthenticated caller" do
    result = execute_graphql('mutation { createVenue(input: { name: "x" }) { venue { name } } }')

    expect(error_codes(result)).to eq([ "UNAUTHENTICATED" ])
    expect(Venue.count).to be_zero
  end
end

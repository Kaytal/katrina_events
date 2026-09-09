require "rails_helper"

# A tripwire, not a description. Every field listed here is a deliberate choice
# about what the public internet can reach; adding a root field without updating
# this spec fails the build, which is the point. §9's "every admin route 401s"
# becomes, on a single endpoint, "every root field is accounted for".
RSpec.describe "Schema surface" do
  PUBLIC_QUERY_FIELDS = %w[eventTypes events health page timeBlock timeBlocks].freeze
  ADMIN_QUERY_FIELDS = %w[admin me].freeze

  PUBLIC_MUTATIONS = %w[login].freeze
  ADMIN_MUTATIONS = %w[
    logout updatePage
    createEvent updateEvent deleteEvent
    createEventException deleteEventException
    createVenue updateVenue
    createAvailabilityPattern updateAvailabilityPattern deleteAvailabilityPattern
    updateTimeBlock materializeTimeBlocks
  ].freeze

  it "exposes only the root query fields we have accounted for" do
    expect(ApiSchema.query.fields.keys.sort)
      .to eq((PUBLIC_QUERY_FIELDS + ADMIN_QUERY_FIELDS).sort)
  end

  it "exposes only the mutations we have accounted for" do
    expect(ApiSchema.mutation.fields.keys.sort)
      .to eq((PUBLIC_MUTATIONS + ADMIN_MUTATIONS).sort)
  end

  describe "every privileged mutation" do
    # Minimal valid arguments per mutation; the point is the auth check, which
    # runs before anything else in the resolver.
    ARGUMENTS = {
      "logout" => "input: {}",
      "updatePage" => 'input: { slug: "about" }',
      "createEvent" => 'input: { eventTypeId: "1", title: "x", startsAt: "2026-04-07T18:00:00-06:00", endsAt: "2026-04-07T19:00:00-06:00" }',
      "updateEvent" => 'input: { id: "1", title: "x" }',
      "deleteEvent" => 'input: { id: "1" }',
      "createEventException" => 'input: { eventId: "1", originalDate: "2026-04-14", action: "skip" }',
      "deleteEventException" => 'input: { id: "1" }',
      "createVenue" => 'input: { name: "x" }',
      "updateVenue" => 'input: { id: "1", name: "x" }',
      "createAvailabilityPattern" => 'input: { eventTypeId: "1", weekday: 2, startTime: "16:00", endTime: "18:00", slotMinutes: 30, capacity: 1, effectiveFrom: "2026-04-01" }',
      "updateAvailabilityPattern" => 'input: { id: "1", capacity: 2 }',
      "deleteAvailabilityPattern" => 'input: { id: "1" }',
      "updateTimeBlock" => 'input: { id: "1", status: "closed" }',
      "materializeTimeBlocks" => "input: {}"
    }.freeze

    ADMIN_MUTATIONS.each do |name|
      it "#{name} refuses an unauthenticated caller" do
        create(:page, slug: "about")

        result = execute_graphql("mutation { #{name}(#{ARGUMENTS.fetch(name)}) { __typename } }")

        expect(error_codes(result)).to eq([ "UNAUTHENTICATED" ]),
                                      "#{name} answered #{result.inspect} instead of refusing"
      end
    end
  end

  it "keeps `me` readable unauthenticated, since it is how the client asks if it is signed in" do
    result = execute_graphql("{ me { email } }")

    expect(result["errors"]).to be_nil
    expect(dig_data(result, "me")).to be_nil
  end

  # Introspection is deliberately on (plan §3) — this pins that as a decision
  # rather than an accident, so turning it off is also a deliberate change.
  it "allows introspection" do
    result = execute_graphql("{ __schema { queryType { name } } }")

    expect(dig_data(result, "__schema", "queryType", "name")).to eq("Query")
  end
end

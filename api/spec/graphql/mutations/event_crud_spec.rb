require "rails_helper"

RSpec.describe "Event CRUD" do
  let(:user) { create(:user) }
  let(:event_type) { create(:event_type) }
  let(:venue) { create(:venue) }

  describe "createEvent" do
    let(:query) do
      <<~GRAPHQL
        mutation Create(
          $eventTypeId: ID!, $venueId: ID, $title: String!,
          $startsAt: ISO8601DateTime!, $endsAt: ISO8601DateTime!,
          $recurrenceRule: String, $bookable: Boolean, $capacity: Int
        ) {
          createEvent(input: {
            eventTypeId: $eventTypeId, venueId: $venueId, title: $title,
            startsAt: $startsAt, endsAt: $endsAt,
            recurrenceRule: $recurrenceRule, bookable: $bookable, capacity: $capacity
          }) {
            event { id title bookable capacity recurring recurrenceRule venue { name } }
            errors { field messages }
          }
        }
      GRAPHQL
    end

    def create_event(overrides = {})
      variables = {
        "eventTypeId" => event_type.id.to_s,
        "title" => "Festival main stage",
        "startsAt" => "2026-04-11T14:00:00-06:00",
        "endsAt" => "2026-04-11T15:00:00-06:00"
      }.merge(overrides)

      execute_as(user, query, variables: variables)
    end

    it "creates an announcement — bookable false, no capacity needed" do
      result = create_event

      expect(dig_data(result, "createEvent", "errors")).to be_empty
      expect(dig_data(result, "createEvent", "event")).to include(
        "title" => "Festival main stage", "bookable" => false, "recurring" => false
      )
    end

    it "creates a recurring bookable class" do
      result = create_event(
        "venueId" => venue.id.to_s,
        "title" => "Littles Dance Class",
        "recurrenceRule" => "FREQ=WEEKLY;BYDAY=TU",
        "bookable" => true,
        "capacity" => 12
      )

      event = dig_data(result, "createEvent", "event")
      expect(event).to include("bookable" => true, "capacity" => 12, "recurring" => true)
      expect(event["venue"]).to include("name" => venue.name)
    end

    it "refuses a bookable event with no capacity, which would generate a block nobody fits in" do
      result = create_event("bookable" => true)

      expect(dig_data(result, "createEvent", "event")).to be_nil
      expect(dig_data(result, "createEvent", "errors").first)
        .to include("field" => "capacity")
    end

    it "refuses an end before the start" do
      result = create_event("endsAt" => "2026-04-11T13:00:00-06:00")

      expect(dig_data(result, "createEvent", "errors").first).to include("field" => "endsAt")
    end

    it "refuses an unparseable recurrence rule" do
      result = create_event("recurrenceRule" => "not a rule")

      expect(dig_data(result, "createEvent", "errors").first)
        .to include("field" => "recurrenceRule")
    end

    # An occurrence is identified by its local date, so sub-daily rules are not
    # representable; emitting only the first of the day would lose sessions.
    it "refuses a sub-daily frequency" do
      result = create_event("recurrenceRule" => "FREQ=HOURLY")

      expect(dig_data(result, "createEvent", "errors").first["messages"].join)
        .to match(/more than once a day/i)
    end

    it "refuses a rule that pins a time of day" do
      result = create_event("recurrenceRule" => "FREQ=WEEKLY;BYDAY=TU;BYHOUR=10,17")

      expect(dig_data(result, "createEvent", "errors").first["messages"].join)
        .to match(/time of day/i)
    end

    it "refuses an unauthenticated caller" do
      result = execute_graphql(query, variables: {
                                 "eventTypeId" => event_type.id.to_s, "title" => "x",
                                 "startsAt" => "2026-04-11T14:00:00-06:00",
                                 "endsAt" => "2026-04-11T15:00:00-06:00"
                               })

      expect(error_codes(result)).to eq([ "UNAUTHENTICATED" ])
      expect(Event.count).to be_zero
    end
  end

  describe "updateEvent" do
    let!(:event) { create(:event, :weekly, event_type: event_type, venue: venue, title: "Class") }

    let(:query) do
      <<~GRAPHQL
        mutation Update(
          $id: ID!, $title: String, $bookable: Boolean, $capacity: Int,
          $status: String, $clearVenue: Boolean, $clearRecurrence: Boolean
        ) {
          updateEvent(input: {
            id: $id, title: $title, bookable: $bookable, capacity: $capacity,
            status: $status, clearVenue: $clearVenue, clearRecurrence: $clearRecurrence
          }) {
            event { id title bookable capacity status recurring recurrenceRule venue { id } }
            errors { field messages }
          }
        }
      GRAPHQL
    end

    def update(overrides)
      execute_as(user, query, variables: { "id" => event.id.to_s }.merge(overrides))
    end

    it "edits a field and leaves the rest alone" do
      update("title" => "Littles Dance Class")

      expect(event.reload).to have_attributes(title: "Littles Dance Class",
                                              recurrence_rule: "FREQ=WEEKLY;BYDAY=TU")
    end

    it "cancels an event without deleting it, keeping the record" do
      update("status" => "cancelled")

      expect(event.reload.status).to eq("cancelled")
      expect(Event.count).to eq(1)
    end

    # A cancelled event must leave the public calendar.
    it "removes a cancelled event from the public expansion" do
      update("status" => "cancelled")

      occurrences = Events::Expansion.call(
        from: event.starts_at - 1.day, to: event.starts_at + 30.days
      )

      expect(occurrences).to be_empty
    end

    it "turns a repeating event into a one-off" do
      update("clearRecurrence" => true)

      expect(event.reload.recurrence_rule).to be_nil
      expect(dig_data(update("clearRecurrence" => true), "updateEvent", "event")["recurring"])
        .to be(false)
    end

    # A GraphQL null argument is indistinguishable from an absent one, so
    # clearing needs its own flag.
    it "detaches a venue when asked explicitly" do
      update("clearVenue" => true)

      expect(event.reload.venue).to be_nil
    end

    it "returns field errors without writing anything" do
      result = update("bookable" => true)

      expect(dig_data(result, "updateEvent", "event")).to be_nil
      expect(dig_data(result, "updateEvent", "errors").first).to include("field" => "capacity")
      expect(event.reload.bookable).to be(false)
    end

    it "refuses an unauthenticated caller" do
      result = execute_graphql(query, variables: { "id" => event.id.to_s, "title" => "Hacked" })

      expect(error_codes(result)).to eq([ "UNAUTHENTICATED" ])
      expect(event.reload.title).to eq("Class")
    end
  end

  describe "deleteEvent" do
    let(:query) { "mutation D($id: ID!) { deleteEvent(input: { id: $id }) { deletedId errors { field } } }" }

    it "removes the event and its exceptions" do
      event = create(:event, :weekly, event_type: event_type)
      create(:event_exception, event: event, original_date: event.starts_at.to_date + 7.days)

      execute_as(user, query, variables: { "id" => event.id.to_s })

      expect(Event.count).to be_zero
      expect(EventException.count).to be_zero
    end

    it "refuses an unauthenticated caller" do
      event = create(:event, event_type: event_type)

      result = execute_graphql(query, variables: { "id" => event.id.to_s })

      expect(error_codes(result)).to eq([ "UNAUTHENTICATED" ])
      expect(Event.count).to eq(1)
    end
  end
end

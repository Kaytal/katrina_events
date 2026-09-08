require "rails_helper"

RSpec.describe "Per-occurrence cancel and move" do
  let(:user) { create(:user) }
  # 6pm Tuesdays from 2026-04-07.
  let!(:event) do
    create(:event, :weekly,
           starts_at: Time.zone.parse("2026-04-07 18:00"),
           ends_at: Time.zone.parse("2026-04-07 19:00"))
  end

  let(:create_query) do
    <<~GRAPHQL
      mutation Except(
        $eventId: ID!, $originalDate: ISO8601Date!, $action: String!,
        $startsAt: ISO8601DateTime, $endsAt: ISO8601DateTime
      ) {
        createEventException(input: {
          eventId: $eventId, originalDate: $originalDate, action: $action,
          startsAt: $startsAt, endsAt: $endsAt
        }) {
          exception { id originalDate action startsAt endsAt }
          errors { field messages }
        }
      }
    GRAPHQL
  end

  def cancel(date)
    execute_as(user, create_query, variables: {
                 "eventId" => event.id.to_s, "originalDate" => date, "action" => "skip"
               })
  end

  def move(date, to_start, to_end)
    execute_as(user, create_query, variables: {
                 "eventId" => event.id.to_s, "originalDate" => date, "action" => "move",
                 "startsAt" => to_start, "endsAt" => to_end
               })
  end

  describe "cancelling one occurrence" do
    it "removes it from the public calendar and leaves the others" do
      cancel("2026-04-14")

      dates = Events::Expansion.call(
        from: Time.zone.parse("2026-04-01"), to: Time.zone.parse("2026-05-01")
      ).map { |o| o.original_date.to_s }

      expect(dates).to eq(%w[2026-04-07 2026-04-21 2026-04-28])
    end

    it "still shows it in the admin list, flagged, so it can be restored" do
      cancel("2026-04-14")

      cancelled = Events::Expansion.call(
        from: Time.zone.parse("2026-04-01"), to: Time.zone.parse("2026-05-01"),
        include_skipped: true
      ).find { |o| o.original_date.to_s == "2026-04-14" }

      expect(cancelled).to be_skipped
      expect(cancelled.starts_at).to eq(Time.zone.parse("2026-04-14 18:00"))
    end

    it "refuses a second exception for the same occurrence" do
      cancel("2026-04-14")
      result = cancel("2026-04-14")

      expect(dig_data(result, "createEventException", "exception")).to be_nil
      expect(dig_data(result, "createEventException", "errors").first["field"])
        .to eq("originalDate")
    end

    # Without this she can cancel a Wednesday on a Tuesday class: a row that
    # matches nothing, does nothing, and looks like a cancelled session.
    it "refuses a date the event does not occur on" do
      result = cancel("2026-04-15")

      expect(dig_data(result, "createEventException", "exception")).to be_nil
      expect(dig_data(result, "createEventException", "errors").first["messages"].join)
        .to match(/not a date this event occurs on/i)
      expect(EventException.count).to be_zero
    end
  end

  describe "moving one occurrence" do
    it "reports the new time while keeping the original date as identity" do
      result = move("2026-04-14", "2026-04-16T17:00:00-06:00", "2026-04-16T18:00:00-06:00")

      expect(dig_data(result, "createEventException", "exception")).to include(
        "originalDate" => "2026-04-14", "action" => "move"
      )

      moved = Events::Expansion.call(
        from: Time.zone.parse("2026-04-01"), to: Time.zone.parse("2026-05-01")
      ).find(&:moved?)

      expect(moved.starts_at).to eq(Time.zone.parse("2026-04-16 17:00"))
      expect(moved.original_date.to_s).to eq("2026-04-14")
    end

    it "refuses a move with no destination" do
      result = execute_as(user, create_query, variables: {
                            "eventId" => event.id.to_s,
                            "originalDate" => "2026-04-14", "action" => "move"
                          })

      expect(dig_data(result, "createEventException", "exception")).to be_nil
      expect(dig_data(result, "createEventException", "errors")).not_to be_empty
    end

    it "refuses a destination ending before it starts" do
      result = move("2026-04-14", "2026-04-16T18:00:00-06:00", "2026-04-16T17:00:00-06:00")

      expect(dig_data(result, "createEventException", "errors")).not_to be_empty
    end

    it "refuses an unrecognised action" do
      result = execute_as(user, create_query, variables: {
                            "eventId" => event.id.to_s,
                            "originalDate" => "2026-04-14", "action" => "postpone"
                          })

      expect(dig_data(result, "createEventException", "errors")).not_to be_empty
    end
  end

  describe "restoring an occurrence" do
    let(:delete_query) do
      "mutation D($id: ID!) { deleteEventException(input: { id: $id }) { deletedId errors { field } } }"
    end

    it "brings a cancelled occurrence back to what the rule says" do
      cancel("2026-04-14")
      exception = EventException.sole

      execute_as(user, delete_query, variables: { "id" => exception.id.to_s })

      dates = Events::Expansion.call(
        from: Time.zone.parse("2026-04-01"), to: Time.zone.parse("2026-05-01")
      ).map { |o| o.original_date.to_s }

      expect(dates).to include("2026-04-14")
    end

    it "returns a moved occurrence to its original time" do
      move("2026-04-14", "2026-04-16T17:00:00-06:00", "2026-04-16T18:00:00-06:00")

      execute_as(user, delete_query, variables: { "id" => EventException.sole.id.to_s })

      restored = Events::Expansion.call(
        from: Time.zone.parse("2026-04-01"), to: Time.zone.parse("2026-05-01")
      ).find { |o| o.original_date.to_s == "2026-04-14" }

      expect(restored.starts_at).to eq(Time.zone.parse("2026-04-14 18:00"))
      expect(restored).not_to be_moved
    end
  end

  describe "authorization" do
    it "refuses to cancel an occurrence unauthenticated" do
      result = execute_graphql(create_query, variables: {
                                 "eventId" => event.id.to_s,
                                 "originalDate" => "2026-04-14", "action" => "skip"
                               })

      expect(error_codes(result)).to eq([ "UNAUTHENTICATED" ])
      expect(EventException.count).to be_zero
    end
  end
end

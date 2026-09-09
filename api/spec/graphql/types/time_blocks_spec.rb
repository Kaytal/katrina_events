require "rails_helper"

RSpec.describe "Time blocks over GraphQL" do
  let(:user) { create(:user) }
  def local(string) = Time.zone.parse(string)

  let(:event) do
    create(:event, :weekly, :bookable,
           title: "Littles Dance Class",
           starts_at: local("2026-04-07 16:30"), ends_at: local("2026-04-07 17:15"),
           capacity: 12, price_note: "$15")
  end

  def materialize
    TimeBlocks::Materializer.call(from: local("2026-04-01 00:00"), to: local("2026-05-01 00:00"))
  end

  describe "Query.timeBlocks" do
    let(:query) do
      <<~GRAPHQL
        query Blocks($from: ISO8601DateTime!, $to: ISO8601DateTime!) {
          timeBlocks(from: $from, to: $to) {
            id startsAt endsAt status capacity spotsRemaining priceNote
            eventType { name }
          }
        }
      GRAPHQL
    end

    def blocks
      dig_data(execute_graphql(query, variables: {
                                 "from" => "2026-04-01T00:00:00-06:00",
                                 "to" => "2026-05-01T00:00:00-06:00"
                               }), "timeBlocks")
    end

    it "lists open slots with the capacity and price they inherit" do
      event
      materialize

      expect(blocks.size).to eq(4)
      expect(blocks.first).to include(
        "status" => "open", "capacity" => 12, "spotsRemaining" => 12, "priceNote" => "$15"
      )
    end

    it "hides closed slots, so nothing unrequestable is advertised" do
      event
      materialize
      TimeBlock.first.update!(status: "closed")

      expect(blocks.size).to eq(3)
    end

    it "hides a slot whose occurrence was cancelled" do
      event
      create(:event_exception, event: event, original_date: Date.new(2026, 4, 14), action: "skip")
      materialize

      expect(blocks.map { |b| b["startsAt"] }.join).not_to include("2026-04-14")
    end

    it "reports an override rather than the inherited value" do
      event
      materialize
      TimeBlock.order(:starts_at).first.update!(capacity: 6, price_note: "Free this week")

      expect(blocks.first).to include("capacity" => 6, "priceNote" => "Free this week")
    end

    it "is public — no token needed" do
      event
      materialize

      result = execute_graphql(query, variables: {
                                 "from" => "2026-04-01T00:00:00-06:00",
                                 "to" => "2026-05-01T00:00:00-06:00"
                               })

      expect(result["errors"]).to be_nil
    end

    # Her notes and the review flag are hers.
    it "does not expose admin-only fields on the public type" do
      expect(Types::TimeBlockType.fields.keys).not_to include("notes", "needsReview", "reviewReason")
    end
  end

  describe "occurrences carrying their block" do
    let(:query) do
      <<~GRAPHQL
        query Events($from: ISO8601DateTime!, $to: ISO8601DateTime!) {
          events(from: $from, to: $to) {
            title bookable spotsRemaining
            timeBlock { id status capacity }
          }
        }
      GRAPHQL
    end

    def occurrences
      dig_data(execute_graphql(query, variables: {
                                 "from" => "2026-04-01T00:00:00-06:00",
                                 "to" => "2026-05-01T00:00:00-06:00"
                               }), "events")
    end

    # §3: the calendar needs no second call.
    it "attaches the slot to its occurrence" do
      event
      materialize

      first = occurrences.first
      expect(first["timeBlock"]).to include("status" => "open", "capacity" => 12)
      expect(first["spotsRemaining"]).to eq(12)
    end

    it "leaves an announcement with no block" do
      create(:event, title: "Festival", bookable: false,
                     starts_at: local("2026-04-11 14:00"), ends_at: local("2026-04-11 15:00"))
      materialize

      announcement = occurrences.find { |o| o["title"] == "Festival" }
      expect(announcement["timeBlock"]).to be_nil
      expect(announcement["spotsRemaining"]).to be_nil
    end

    it "matches the moved occurrence to its own block, not another date's" do
      event
      create(:event_exception, :move, event: event,
                                      original_date: Date.new(2026, 4, 14),
                                      starts_at: local("2026-04-16 17:00"),
                                      ends_at: local("2026-04-16 17:45"))
      materialize

      moved_block = TimeBlock.find_by(original_date: Date.new(2026, 4, 14))
      expect(moved_block.starts_at).to eq(local("2026-04-16 17:00"))

      ids = occurrences.filter_map { |o| o.dig("timeBlock", "id") }
      expect(ids).to include(moved_block.id.to_s)
      expect(ids.uniq.size).to eq(ids.size)
    end
  end

  describe "Admin.timeBlocks" do
    let(:query) do
      <<~GRAPHQL
        query Admin($from: ISO8601DateTime!, $to: ISO8601DateTime!) {
          admin {
            timeBlocks(from: $from, to: $to) {
              id status capacityOverride effectiveCapacity inheritedCapacity
              overridden needsReview reviewReason sourceKind sourceTitle
            }
          }
        }
      GRAPHQL
    end

    def admin_blocks
      dig_data(execute_as(user, query, variables: {
                            "from" => "2026-04-01T00:00:00-06:00",
                            "to" => "2026-05-01T00:00:00-06:00"
                          }), "admin", "timeBlocks")
    end

    it "shows what a slot inherits alongside what she overrode" do
      event
      materialize
      TimeBlock.order(:starts_at).first.update!(capacity: 6)

      first = admin_blocks.first
      expect(first).to include(
        "capacityOverride" => 6, "inheritedCapacity" => 12,
        "effectiveCapacity" => 6, "overridden" => true, "sourceKind" => "event"
      )
    end

    it "includes closed slots, which the public query hides" do
      event
      materialize
      TimeBlock.first.update!(status: "closed")

      expect(admin_blocks.map { |b| b["status"] }).to include("closed")
    end

    it "refuses without a token" do
      event
      materialize

      result = execute_graphql(query, variables: {
                                 "from" => "2026-04-01T00:00:00-06:00",
                                 "to" => "2026-05-01T00:00:00-06:00"
                               })

      expect(error_codes(result)).to eq([ "UNAUTHENTICATED" ])
    end
  end

  describe "updateTimeBlock" do
    let(:query) do
      <<~GRAPHQL
        mutation Update($id: ID!, $status: String, $capacity: Int, $resetCapacity: Boolean, $clearReview: Boolean) {
          updateTimeBlock(input: {
            id: $id, status: $status, capacity: $capacity,
            resetCapacity: $resetCapacity, clearReview: $clearReview
          }) {
            timeBlock { status capacityOverride effectiveCapacity overridden needsReview }
            errors { field messages }
          }
        }
      GRAPHQL
    end

    def update(block, overrides)
      execute_as(user, query, variables: { "id" => block.id.to_s }.merge(overrides))
    end

    it "overrides capacity for one slot only" do
      event
      materialize
      block = TimeBlock.order(:starts_at).first

      result = update(block, "capacity" => 6)

      expect(dig_data(result, "updateTimeBlock", "timeBlock"))
        .to include("capacityOverride" => 6, "effectiveCapacity" => 6, "overridden" => true)
      expect(TimeBlock.order(:starts_at).second.effective_capacity).to eq(12)
    end

    # Without a way back, the first override she sets can never be undone.
    it "resets to inherited" do
      event
      materialize
      block = TimeBlock.order(:starts_at).first
      block.update!(capacity: 6)

      result = update(block, "resetCapacity" => true)

      expect(dig_data(result, "updateTimeBlock", "timeBlock"))
        .to include("capacityOverride" => nil, "effectiveCapacity" => 12, "overridden" => false)
    end

    it "closes a slot, and regeneration leaves it closed" do
      event
      materialize
      block = TimeBlock.order(:starts_at).first

      update(block, "status" => "closed")
      materialize

      expect(block.reload.status).to eq("closed")
      expect(block.auto_closed).to be(false)
    end

    it "dismisses a review flag once she has dealt with it" do
      event
      materialize
      block = TimeBlock.order(:starts_at).first
      block.flag_for_review!("something happened")

      result = update(block, "clearReview" => true)

      expect(dig_data(result, "updateTimeBlock", "timeBlock")).to include("needsReview" => false)
    end

    it "refuses without a token" do
      event
      materialize
      block = TimeBlock.first

      result = execute_graphql(query, variables: { "id" => block.id.to_s, "status" => "closed" })

      expect(error_codes(result)).to eq([ "UNAUTHENTICATED" ])
      expect(block.reload.status).to eq("open")
    end
  end

  describe "the override floor" do
    # She must not be able to un-approve someone by editing a number.
    it "refuses an override below the number already approved" do
      event
      materialize
      block = TimeBlock.order(:starts_at).first
      allow_any_instance_of(TimeBlock).to receive(:approved_count).and_return(8)

      result = execute_as(user, <<~GRAPHQL, variables: { "id" => block.id.to_s })
        mutation Update($id: ID!) {
          updateTimeBlock(input: { id: $id, capacity: 3 }) {
            timeBlock { capacityOverride }
            errors { field messages }
          }
        }
      GRAPHQL

      expect(dig_data(result, "updateTimeBlock", "timeBlock")).to be_nil
      error = dig_data(result, "updateTimeBlock", "errors").first
      expect(error["field"]).to eq("capacity")
      expect(error["messages"].join).to match(/below the 8 already approved/i)
      expect(error["messages"].join).to match(/close the block instead/i)
    end
  end
end

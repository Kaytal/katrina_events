require "rails_helper"

RSpec.describe "Availability pattern CRUD" do
  let(:user) { create(:user) }
  let(:event_type) { create(:event_type) }

  let(:create_query) do
    <<~GRAPHQL
      mutation Create(
        $eventTypeId: ID!, $weekday: Int!, $startTime: String!, $endTime: String!,
        $slotMinutes: Int!, $capacity: Int!, $effectiveFrom: ISO8601Date!
      ) {
        createAvailabilityPattern(input: {
          eventTypeId: $eventTypeId, weekday: $weekday, startTime: $startTime,
          endTime: $endTime, slotMinutes: $slotMinutes, capacity: $capacity,
          effectiveFrom: $effectiveFrom
        }) {
          availabilityPattern { id weekday startTime endTime slotMinutes capacity slotCount active }
          errors { field messages }
        }
      }
    GRAPHQL
  end

  def create_pattern(overrides = {})
    variables = {
      "eventTypeId" => event_type.id.to_s, "weekday" => 2,
      "startTime" => "16:00", "endTime" => "18:00",
      "slotMinutes" => 30, "capacity" => 1, "effectiveFrom" => "2026-04-01"
    }.merge(overrides)

    execute_as(user, create_query, variables: variables)
  end

  it "creates a template and reports how many slots a day produces" do
    result = create_pattern

    expect(dig_data(result, "createAvailabilityPattern", "availabilityPattern")).to include(
      "weekday" => 2, "startTime" => "16:00", "endTime" => "18:00",
      "slotMinutes" => 30, "capacity" => 1, "slotCount" => 4, "active" => true
    )
  end

  # A `time` column that went through the app zone would come back shifted.
  it "stores the wall-clock time it was given" do
    create_pattern("startTime" => "16:00", "endTime" => "18:00")

    pattern = AvailabilityPattern.sole
    expect(pattern.start_time.strftime("%H:%M")).to eq("16:00")
    expect(pattern.end_time.strftime("%H:%M")).to eq("18:00")
  end

  it "queues materialization so the slots exist without waiting for the nightly run" do
    expect { create_pattern }.to have_enqueued_job(MaterializeTimeBlocksJob)
  end

  # 4–6pm at 45 minutes silently loses the last half hour otherwise.
  it "refuses a slot length that does not divide the window evenly" do
    result = create_pattern("slotMinutes" => 45)

    expect(dig_data(result, "createAvailabilityPattern", "availabilityPattern")).to be_nil
    expect(dig_data(result, "createAvailabilityPattern", "errors").first["messages"].join)
      .to match(/does not divide the window evenly/i)
  end

  it "refuses an end before the start" do
    result = create_pattern("endTime" => "15:00")

    expect(dig_data(result, "createAvailabilityPattern", "errors")).not_to be_empty
  end

  it "refuses a weekday outside 0..6" do
    result = create_pattern("weekday" => 9)

    expect(dig_data(result, "createAvailabilityPattern", "errors").first["field"]).to eq("weekday")
  end

  it "refuses an unauthenticated caller" do
    result = execute_graphql(create_query, variables: {
                               "eventTypeId" => event_type.id.to_s, "weekday" => 2,
                               "startTime" => "16:00", "endTime" => "18:00",
                               "slotMinutes" => 30, "capacity" => 1, "effectiveFrom" => "2026-04-01"
                             })

    expect(error_codes(result)).to eq([ "UNAUTHENTICATED" ])
    expect(AvailabilityPattern.count).to be_zero
  end

  describe "deleting" do
    let(:delete_query) do
      "mutation D($id: ID!) { deleteAvailabilityPattern(input: { id: $id }) { deletedId errors { field messages } } }"
    end

    it "retires its slots rather than orphaning them" do
      pattern = create(:availability_pattern, event_type: event_type,
                                              effective_from: Date.new(2026, 4, 1))
      TimeBlocks::Materializer.call(from: Time.zone.parse("2026-04-01"),
                                    to: Time.zone.parse("2026-05-01"))
      expect(TimeBlock.count).to be_positive

      execute_as(user, delete_query, variables: { "id" => pattern.id.to_s })

      expect(AvailabilityPattern.count).to be_zero
      expect(TimeBlock.count).to be_zero
    end

    # Detaching the held slot to force the delete through would leave a slot
    # nothing regenerates and nothing tidies — the orphan the model now refuses
    # to create. Deactivating is the action she actually wants.
    it "refuses while a slot has requests, and says to turn it off instead" do
      pattern = create(:availability_pattern, event_type: event_type,
                                              effective_from: Date.new(2026, 4, 1))
      TimeBlocks::Materializer.call(from: Time.zone.parse("2026-04-01"),
                                    to: Time.zone.parse("2026-05-01"))
      held = TimeBlock.order(:starts_at).first
      allow_any_instance_of(TimeBlock).to receive(:requested_count) do |instance|
        instance.id == held.id ? 1 : 0
      end

      result = execute_as(user, delete_query, variables: { "id" => pattern.id.to_s })

      expect(dig_data(result, "deleteAvailabilityPattern", "deletedId")).to be_nil
      expect(dig_data(result, "deleteAvailabilityPattern", "errors").first["messages"].join)
        .to match(/turn it off instead/i)

      expect(AvailabilityPattern.count).to eq(1)
      expect(held.reload).to be_present
      expect(held).to be_needs_review
      expect(held.review_reason).to match(/already asked for it/i)
      # And it never becomes an orphan.
      expect(held.availability_pattern_id).to eq(pattern.id)
    end

    it "still retires the free slots even when it refuses" do
      pattern = create(:availability_pattern, event_type: event_type,
                                              effective_from: Date.new(2026, 4, 1))
      TimeBlocks::Materializer.call(from: Time.zone.parse("2026-04-01"),
                                    to: Time.zone.parse("2026-05-01"))
      held = TimeBlock.order(:starts_at).first
      allow_any_instance_of(TimeBlock).to receive(:requested_count) do |instance|
        instance.id == held.id ? 1 : 0
      end

      execute_as(user, delete_query, variables: { "id" => pattern.id.to_s })

      expect(TimeBlock.count).to eq(1)
      expect(TimeBlock.sole.id).to eq(held.id)
    end
  end

  describe "updating" do
    it "regenerates after a change" do
      pattern = create(:availability_pattern, event_type: event_type)

      expect do
        execute_as(user, <<~GRAPHQL, variables: { "id" => pattern.id.to_s })
          mutation U($id: ID!) {
            updateAvailabilityPattern(input: { id: $id, capacity: 2 }) {
              availabilityPattern { capacity }
              errors { field }
            }
          }
        GRAPHQL
      end.to have_enqueued_job(MaterializeTimeBlocksJob)

      expect(pattern.reload.capacity).to eq(2)
    end
  end
end

RSpec.describe MaterializeTimeBlocksJob do
  it "materializes over a rolling window and reports what it did" do
    create(:event, :weekly, :bookable,
           starts_at: 2.days.from_now.change(hour: 16), ends_at: 2.days.from_now.change(hour: 17),
           capacity: 10)

    result = described_class.perform_now

    expect(result.created).to be_positive
    expect(TimeBlock.count).to eq(result.created)
  end

  it "is idempotent across runs" do
    create(:event, :weekly, :bookable,
           starts_at: 2.days.from_now.change(hour: 16), ends_at: 2.days.from_now.change(hour: 17),
           capacity: 10)

    described_class.perform_now
    before = TimeBlock.order(:starts_at).pluck(:id)
    second = described_class.perform_now

    expect(TimeBlock.order(:starts_at).pluck(:id)).to eq(before)
    expect(second.created).to be_zero
  end
end

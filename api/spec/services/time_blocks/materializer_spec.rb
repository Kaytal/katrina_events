require "rails_helper"

RSpec.describe TimeBlocks::Materializer do
  def local(string) = Time.zone.parse(string)

  let(:window) { { from: local("2026-04-01 00:00"), to: local("2026-05-01 00:00") } }

  def materialize(**overrides)
    described_class.call(**window, **overrides)
  end

  # Nothing here can query booking_requests, which does not exist until Phase 8.
  # Everything that needs to know how many people are in a block goes through
  # TimeBlock#requested_count / #approved_count, so the protection rule is real
  # logic tested by stubbing exactly those.
  def pretend_requested(block, count = 1)
    allow(TimeBlock).to receive(:find_by).and_call_original
    allow_any_instance_of(TimeBlock).to receive(:requested_count) do |instance|
      instance.id == block.id ? count : 0
    end
  end

  describe "the event generator" do
    let(:event) do
      create(:event, :weekly, :bookable,
             title: "Littles Dance Class",
             starts_at: local("2026-04-07 16:30"), ends_at: local("2026-04-07 17:15"),
             capacity: 12, price_note: "$15")
    end

    it "makes one block per occurrence, spanning the whole occurrence" do
      event
      materialize

      blocks = TimeBlock.order(:starts_at)
      expect(blocks.count).to eq(4)
      expect(blocks.first.starts_at).to eq(local("2026-04-07 16:30"))
      expect(blocks.first.ends_at).to eq(local("2026-04-07 17:15"))
    end

    # The distinction the plan is emphatic about.
    it "makes one block of capacity 12, not twelve blocks" do
      event
      materialize

      expect(TimeBlock.count).to eq(4)
      expect(TimeBlock.first.effective_capacity).to eq(12)
    end

    it "leaves capacity and price null on the row, so they inherit" do
      event
      materialize

      block = TimeBlock.first
      expect(block.capacity).to be_nil
      expect(block.price_note).to be_nil
      expect(block.effective_capacity).to eq(12)
      expect(block.effective_price_note).to eq("$15")
    end

    it "generates nothing for an announcement" do
      create(:event, :weekly, bookable: false,
                              starts_at: local("2026-04-07 16:30"), ends_at: local("2026-04-07 17:15"))

      materialize

      expect(TimeBlock.count).to be_zero
    end

    it "is idempotent — a second run changes nothing" do
      event
      materialize
      before = TimeBlock.order(:starts_at).pluck(:id, :starts_at)

      result = materialize

      expect(TimeBlock.order(:starts_at).pluck(:id, :starts_at)).to eq(before)
      expect(result.created).to be_zero
      expect(result.removed).to be_zero
    end

    describe "inheritance on edit" do
      # The whole reason capacity is nullable rather than copied down.
      it "reaches every un-overridden block when the class capacity changes" do
        event
        materialize

        event.update!(capacity: 15)

        expect(TimeBlock.all.map(&:effective_capacity)).to all(eq(15))
      end

      it "leaves a deliberate override alone when the class capacity changes" do
        event
        materialize
        overridden = TimeBlock.order(:starts_at).second
        overridden.update!(capacity: 6)

        event.update!(capacity: 15)
        materialize

        expect(overridden.reload.capacity).to eq(6)
        expect(overridden.effective_capacity).to eq(6)
      end

      # "Her exception quietly reverts the next time the nightly job runs" is
      # exactly the bug this guards.
      it "preserves an override across regeneration" do
        event
        materialize
        block = TimeBlock.order(:starts_at).first
        block.update!(capacity: 6, price_note: "Free this week")

        3.times { materialize }

        expect(block.reload).to have_attributes(capacity: 6, price_note: "Free this week")
      end
    end

    describe "exception propagation" do
      it "closes the block of a cancelled occurrence rather than deleting it" do
        event
        materialize
        create(:event_exception, event: event, original_date: Date.new(2026, 4, 14), action: "skip")

        materialize

        block = TimeBlock.find_by(original_date: Date.new(2026, 4, 14))
        expect(block).to be_present
        expect(block.status).to eq("closed")
      end

      it "reopens the block when the cancellation is undone" do
        event
        exception = create(:event_exception, event: event,
                                             original_date: Date.new(2026, 4, 14), action: "skip")
        materialize
        expect(TimeBlock.find_by(original_date: Date.new(2026, 4, 14)).status).to eq("closed")

        exception.destroy!
        materialize

        expect(TimeBlock.find_by(original_date: Date.new(2026, 4, 14)).status).to eq("open")
      end

      # Regeneration must never undo a decision she made by hand.
      it "does not reopen a block she closed herself" do
        event
        materialize
        block = TimeBlock.order(:starts_at).first
        block.update!(status: "closed", auto_closed: false)

        materialize

        expect(block.reload.status).to eq("closed")
      end

      it "moves the block when the occurrence moves, keeping the same row" do
        event
        materialize
        block = TimeBlock.find_by(original_date: Date.new(2026, 4, 14))

        create(:event_exception, :move, event: event,
                                        original_date: Date.new(2026, 4, 14),
                                        starts_at: local("2026-04-16 17:00"),
                                        ends_at: local("2026-04-16 17:45"))
        materialize

        expect(block.reload.starts_at).to eq(local("2026-04-16 17:00"))
        expect(TimeBlock.where(original_date: Date.new(2026, 4, 14)).count).to eq(1)
      end
    end

    describe "cleaning up" do
      it "removes future blocks when the event stops being bookable" do
        event
        materialize
        expect(TimeBlock.count).to eq(4)

        event.update!(bookable: false)
        materialize

        expect(TimeBlock.count).to be_zero
      end

      it "removes blocks when the event is cancelled" do
        event
        materialize

        event.update!(status: "cancelled")
        materialize

        expect(TimeBlock.count).to be_zero
      end

      it "removes blocks for occurrences the rule no longer produces" do
        event
        materialize

        event.update!(recurrence_until: local("2026-04-15 00:00"))
        materialize

        expect(TimeBlock.pluck(:original_date).map(&:to_s)).to eq(%w[2026-04-07 2026-04-14])
      end
    end

    describe "THE PROTECTION RULE" do
      it "never deletes a block that has requests — it flags it instead" do
        event
        materialize
        held = TimeBlock.order(:starts_at).last
        pretend_requested(held)

        event.update!(bookable: false)
        result = materialize

        expect(held.reload).to be_present
        expect(held).to be_needs_review
        expect(held.review_reason).to match(/no longer on the schedule/i)
        expect(result.flagged).to eq(1)
      end

      it "never silently moves a block that has requests" do
        event
        materialize
        held = TimeBlock.find_by(original_date: Date.new(2026, 4, 14))
        pretend_requested(held)

        create(:event_exception, :move, event: event,
                                        original_date: Date.new(2026, 4, 14),
                                        starts_at: local("2026-04-16 17:00"),
                                        ends_at: local("2026-04-16 17:45"))
        materialize

        expect(held.reload.starts_at).to eq(local("2026-04-14 16:30"))
        expect(held).to be_needs_review
        expect(held.review_reason).to match(/people have already asked for the old time/i)
      end

      it "flags a cancellation that strands people, and still closes the block" do
        event
        materialize
        held = TimeBlock.find_by(original_date: Date.new(2026, 4, 14))
        pretend_requested(held)

        create(:event_exception, event: event,
                                 original_date: Date.new(2026, 4, 14), action: "skip")
        materialize

        expect(held.reload.status).to eq("closed")
        expect(held).to be_needs_review
        expect(held.review_reason).to match(/already approved/i)
      end

      it "still replaces freely when nothing has been requested" do
        event
        materialize

        event.update!(bookable: false)
        result = materialize

        expect(TimeBlock.count).to be_zero
        expect(result.flagged).to be_zero
      end

      it "does not re-flag the same block on every run" do
        event
        materialize
        held = TimeBlock.order(:starts_at).last
        pretend_requested(held)
        event.update!(bookable: false)

        materialize
        second = materialize

        expect(second.flagged).to be_zero
      end
    end
  end

  describe "the pattern generator" do
    let(:pattern) do
      create(:availability_pattern,
             weekday: 2, start_time: "16:00", end_time: "18:00",
             slot_minutes: 30, capacity: 1, effective_from: Date.new(2026, 4, 1))
    end

    it "makes (end − start) / slot_minutes blocks per covered day" do
      pattern
      materialize

      april_7 = TimeBlock.where(starts_at: local("2026-04-07 00:00")..local("2026-04-08 00:00"))
      expect(april_7.count).to eq(4)
      expect(april_7.order(:starts_at).map { |b| b.starts_at.strftime("%H:%M") })
        .to eq(%w[16:00 16:30 17:00 17:30])
    end

    it "gives each slot the pattern's capacity, inherited not copied" do
      pattern
      materialize

      block = TimeBlock.first
      expect(block.capacity).to be_nil
      expect(block.effective_capacity).to eq(1)

      pattern.update!(capacity: 2)
      expect(block.reload.effective_capacity).to eq(2)
    end

    it "only covers its own weekday" do
      pattern
      materialize

      expect(TimeBlock.all.map { |b| b.starts_at.to_date.wday }.uniq).to eq([ 2 ])
    end

    it "respects the effective range" do
      create(:availability_pattern, weekday: 2, start_time: "16:00", end_time: "17:00",
                                    slot_minutes: 60,
                                    effective_from: Date.new(2026, 4, 8),
                                    effective_to: Date.new(2026, 4, 20))

      materialize

      expect(TimeBlock.pluck(:starts_at).map { |t| t.to_date.to_s })
        .to eq(%w[2026-04-14])
    end

    it "removes future slots when the pattern is deactivated" do
      pattern
      materialize
      expect(TimeBlock.count).to be_positive

      pattern.update!(active: false)
      materialize

      expect(TimeBlock.count).to be_zero
    end

    it "is idempotent" do
      pattern
      materialize
      before = TimeBlock.order(:starts_at).pluck(:id)

      materialize

      expect(TimeBlock.order(:starts_at).pluck(:id)).to eq(before)
    end

    it "never deletes a requested slot when the pattern is deactivated" do
      pattern
      materialize
      held = TimeBlock.order(:starts_at).first
      pretend_requested(held)

      pattern.update!(active: false)
      materialize

      expect(held.reload).to be_present
      expect(held).to be_needs_review
    end
  end

  describe "both generators together" do
    it "keeps event blocks and pattern blocks in the one table, distinguishable" do
      create(:event, :weekly, :bookable,
             starts_at: local("2026-04-07 16:30"), ends_at: local("2026-04-07 17:15"), capacity: 12)
      create(:availability_pattern, weekday: 4, start_time: "10:00", end_time: "11:00",
                                    slot_minutes: 60, effective_from: Date.new(2026, 4, 1))

      materialize

      expect(TimeBlock.where.not(event_id: nil).count).to eq(4)
      expect(TimeBlock.where.not(availability_pattern_id: nil).count).to eq(5)
      expect(TimeBlock.where.not(event_id: nil).where.not(availability_pattern_id: nil)).to be_empty
    end
  end

  describe "orphan safety" do
    # A source-less block is legitimate (she can make one by hand), so nothing
    # would complain if destroying a pattern quietly created 52 of them.
    it "refuses to destroy a pattern that still owns slots" do
      pattern = create(:availability_pattern, effective_from: Date.new(2026, 4, 1))
      materialize
      expect(TimeBlock.count).to be_positive

      expect(pattern.destroy).to be(false)
      expect(pattern.errors[:base].join).to match(/time blocks/i)
      expect(TimeBlock.where(availability_pattern_id: nil, event_id: nil)).to be_empty
    end

    it "can be destroyed once its slots have been retired" do
      pattern = create(:availability_pattern, effective_from: Date.new(2026, 4, 1))
      materialize

      pattern.time_blocks.destroy_all

      expect(pattern.destroy).to be_truthy
    end
  end

  describe "guardrails" do
    it "refuses a backwards window" do
      expect { described_class.call(from: local("2026-05-01"), to: local("2026-04-01")) }
        .to raise_error(ArgumentError)
    end
  end
end

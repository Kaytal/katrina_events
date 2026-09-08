require "rails_helper"

RSpec.describe Events::Expansion do
  def expand(from:, to:)
    described_class.call(from: from, to: to)
  end

  def local(string)
    Time.zone.parse(string)
  end

  describe "one-off events" do
    it "returns an event that overlaps the window" do
      event = create(:event, starts_at: local("2026-04-07 18:00"), ends_at: local("2026-04-07 19:00"))

      occurrences = expand(from: local("2026-04-01 00:00"), to: local("2026-05-01 00:00"))

      expect(occurrences.map(&:event)).to eq([ event ])
      expect(occurrences.first.starts_at).to eq(local("2026-04-07 18:00"))
    end

    it "excludes an event entirely outside the window" do
      create(:event, starts_at: local("2026-01-07 18:00"), ends_at: local("2026-01-07 19:00"))

      expect(expand(from: local("2026-04-01 00:00"), to: local("2026-05-01 00:00"))).to be_empty
    end

    # A festival that started yesterday and runs through today belongs on today.
    it "includes an occurrence that began before the window but runs into it" do
      create(:event, starts_at: local("2026-03-31 20:00"), ends_at: local("2026-04-01 02:00"))

      expect(expand(from: local("2026-04-01 00:00"), to: local("2026-04-02 00:00")).size).to eq(1)
    end

    it "excludes cancelled events" do
      create(:event, :cancelled, starts_at: local("2026-04-07 18:00"), ends_at: local("2026-04-07 19:00"))

      expect(expand(from: local("2026-04-01 00:00"), to: local("2026-05-01 00:00"))).to be_empty
    end
  end

  describe "weekly recurrence" do
    let!(:event) do
      create(:event, :weekly,
             starts_at: local("2026-04-07 18:00"), ends_at: local("2026-04-07 19:00"))
    end

    it "produces one occurrence per week, at the same wall-clock time" do
      occurrences = expand(from: local("2026-04-01 00:00"), to: local("2026-05-01 00:00"))

      expect(occurrences.map { |o| o.starts_at.strftime("%Y-%m-%d %H:%M") }).to eq(
        [ "2026-04-07 18:00", "2026-04-14 18:00", "2026-04-21 18:00", "2026-04-28 18:00" ]
      )
    end

    it "carries the duration onto every occurrence" do
      occurrences = expand(from: local("2026-04-01 00:00"), to: local("2026-05-01 00:00"))

      expect(occurrences).to all(satisfy { |o| o.ends_at - o.starts_at == 1.hour })
    end

    it "returns occurrences in chronological order across several events" do
      create(:event, starts_at: local("2026-04-09 10:00"), ends_at: local("2026-04-09 11:00"))

      occurrences = expand(from: local("2026-04-01 00:00"), to: local("2026-04-20 00:00"))

      expect(occurrences.map(&:starts_at)).to eq(occurrences.map(&:starts_at).sort)
    end

    it "stops at recurrence_until" do
      event.update!(recurrence_until: local("2026-04-15 00:00"))

      occurrences = expand(from: local("2026-04-01 00:00"), to: local("2026-05-01 00:00"))

      expect(occurrences.map { |o| o.starts_at.to_date.to_s }).to eq(%w[2026-04-07 2026-04-14])
    end

    it "gives each occurrence a stable, distinct id" do
      ids = expand(from: local("2026-04-01 00:00"), to: local("2026-05-01 00:00")).map(&:id)
      again = expand(from: local("2026-04-01 00:00"), to: local("2026-05-01 00:00")).map(&:id)

      expect(ids.uniq.size).to eq(ids.size)
      expect(again).to eq(ids)
    end
  end

  # The plan calls this out as where the bugs will be, so both Denver
  # transitions are pinned explicitly rather than trusted to the library.
  describe "DST boundaries in America/Denver" do
    it "keeps a 6pm Tuesday class at 6pm across the spring-forward transition" do
      # 2026-03-08: 2am jumps to 3am. Tuesdays either side are 03-03 and 03-10.
      create(:event, :weekly,
             starts_at: local("2026-03-03 18:00"), ends_at: local("2026-03-03 19:00"))

      occurrences = expand(from: local("2026-03-01 00:00"), to: local("2026-03-20 00:00"))

      expect(occurrences.map { |o| o.starts_at.strftime("%Y-%m-%d %H:%M %Z") }).to eq(
        [ "2026-03-03 18:00 MST", "2026-03-10 18:00 MDT", "2026-03-17 18:00 MDT" ]
      )
    end

    it "keeps a 6pm Tuesday class at 6pm across the fall-back transition" do
      # 2026-11-01: 1am–2am happens twice. Tuesdays either side are 10-27 and 11-03.
      create(:event, :weekly,
             starts_at: local("2026-10-27 18:00"), ends_at: local("2026-10-27 19:00"))

      occurrences = expand(from: local("2026-10-20 00:00"), to: local("2026-11-15 00:00"))

      expect(occurrences.map { |o| o.starts_at.strftime("%Y-%m-%d %H:%M %Z") }).to eq(
        [ "2026-10-27 18:00 MDT", "2026-11-03 18:00 MST", "2026-11-10 18:00 MST" ]
      )
    end

    it "changes UTC offset across the transition while local time holds steady" do
      create(:event, :weekly,
             starts_at: local("2026-03-03 18:00"), ends_at: local("2026-03-03 19:00"))

      before, after = expand(from: local("2026-03-01 00:00"), to: local("2026-03-15 00:00"))

      expect(before.starts_at.utc_offset).to eq(-7.hours)
      expect(after.starts_at.utc_offset).to eq(-6.hours)
      expect(after.starts_at - before.starts_at).to eq(6.days + 23.hours)
    end

    # The naive failure mode: expanding in UTC emits 1:30am twice on the
    # fall-back date, because that wall-clock hour occurs twice.
    it "emits exactly one occurrence on the fall-back date, not a duplicate" do
      create(:event, :weekly,
             starts_at: local("2026-10-25 01:30"), ends_at: local("2026-10-25 02:30"),
             recurrence_rule: "FREQ=DAILY")

      occurrences = expand(from: local("2026-11-01 00:00"), to: local("2026-11-02 00:00"))

      expect(occurrences.size).to eq(1)
      expect(occurrences.first.starts_at.strftime("%H:%M")).to eq("01:30")
    end

    # 2:30am does not exist on 2026-03-08; inventing a time is worse than
    # dropping the occurrence.
    it "omits an occurrence whose wall-clock time the spring-forward skips" do
      create(:event, starts_at: local("2026-03-01 02:30"), ends_at: local("2026-03-01 03:30"),
                     recurrence_rule: "FREQ=DAILY")

      occurrences = expand(from: local("2026-03-07 00:00"), to: local("2026-03-10 00:00"))

      dates = occurrences.map { |o| o.starts_at.to_date.to_s }
      expect(dates).to include("2026-03-07", "2026-03-09")
      expect(dates).not_to include("2026-03-08")
    end
  end

  describe "exceptions" do
    let!(:event) do
      create(:event, :weekly,
             starts_at: local("2026-04-07 18:00"), ends_at: local("2026-04-07 19:00"))
    end

    it "drops a skipped occurrence and leaves the rest alone" do
      create(:event_exception, event: event, original_date: Date.new(2026, 4, 14), action: "skip")

      occurrences = expand(from: local("2026-04-01 00:00"), to: local("2026-05-01 00:00"))

      expect(occurrences.map { |o| o.original_date.to_s })
        .to eq(%w[2026-04-07 2026-04-21 2026-04-28])
    end

    it "moves an occurrence to its new time, keeping the original date as its identity" do
      create(:event_exception, :move, event: event,
                                      original_date: Date.new(2026, 4, 14),
                                      starts_at: local("2026-04-16 17:00"),
                                      ends_at: local("2026-04-16 18:00"))

      moved = expand(from: local("2026-04-01 00:00"), to: local("2026-05-01 00:00"))
              .find(&:moved?)

      expect(moved.starts_at).to eq(local("2026-04-16 17:00"))
      expect(moved.ends_at).to eq(local("2026-04-16 18:00"))
      expect(moved.original_date).to eq(Date.new(2026, 4, 14))
      expect(moved.id).to eq("#{event.id}:2026-04-14")
    end

    it "includes an occurrence moved into the window from outside it" do
      create(:event_exception, :move, event: event,
                                      original_date: Date.new(2026, 4, 28),
                                      starts_at: local("2026-05-02 10:00"),
                                      ends_at: local("2026-05-02 11:00"))

      occurrences = expand(from: local("2026-05-01 00:00"), to: local("2026-05-05 00:00"))

      expect(occurrences.map(&:starts_at)).to include(local("2026-05-02 10:00"))
    end

    it "excludes an occurrence moved out of the window" do
      create(:event_exception, :move, event: event,
                                      original_date: Date.new(2026, 4, 14),
                                      starts_at: local("2026-06-01 18:00"),
                                      ends_at: local("2026-06-01 19:00"))

      dates = expand(from: local("2026-04-13 00:00"), to: local("2026-04-15 00:00"))
              .map { |o| o.original_date.to_s }

      expect(dates).not_to include("2026-04-14")
    end
  end

  describe "guardrails" do
    it "refuses a backwards range" do
      expect { expand(from: local("2026-05-01 00:00"), to: local("2026-04-01 00:00")) }
        .to raise_error(ArgumentError)
    end

    # An unbounded weekly rule means the window is the only thing limiting work.
    it "refuses a range wide enough to be a denial of service" do
      expect { expand(from: local("2026-01-01 00:00"), to: local("2030-01-01 00:00")) }
        .to raise_error(described_class::RangeTooLarge)
    end
  end
end

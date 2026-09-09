module TimeBlocks
  # Shared reconciliation: given the blocks a source *should* have in a window
  # and the ones it *does* have, create, update, and remove — subject to the
  # protection rule.
  class Generator
    def initialize(source, from, to, result)
      @source = source
      @from = from
      @to = to
      @result = result
    end

    private

    attr_reader :source, :from, :to, :result

    # `desired` is a hash of identity => attributes.
    def reconcile(desired, existing)
      desired.each do |identity, attributes|
        block = existing[identity]

        block.nil? ? create(attributes) : update(block, attributes)
      end

      (existing.keys - desired.keys).each { |identity| remove(existing[identity]) }
    end

    def create(attributes)
      TimeBlock.create!(attributes)
      result.created += 1
    rescue ActiveRecord::RecordNotUnique
      # A concurrent run got there first. Its row is as good as ours.
      nil
    end

    def update(block, attributes)
      moved = block.starts_at != attributes[:starts_at] || block.ends_at != attributes[:ends_at]

      if moved && block.protected_from_regeneration?
        # Never silently move a block someone has asked for. Leave it where it
        # is and tell her, because the people holding requests were told a time.
        flag(block, "This session moved, but people have already asked for the " \
                    "old time. Move or cancel it yourself so they can be told.")
        return
      end

      apply_status(block, attributes)
      block.assign_attributes(attributes.except(:status, :auto_closed))
      return unless block.changed?

      block.save!
      result.updated += 1
    end

    # Only ever forces "closed", never forces "open": she may have closed a
    # block by hand, and regeneration must not undo that. `auto_closed` is what
    # separates a close this code made from one she made.
    def apply_status(block, attributes)
      should_close = attributes[:status] == TimeBlock::CLOSED

      if should_close
        if block.protected_from_regeneration? && !block.auto_closed?
          flag(block, "This session was cancelled, but people are already " \
                      "approved for it. Let them know before it comes round.")
        end
        block.status = TimeBlock::CLOSED
        block.auto_closed = true
      elsif block.auto_closed?
        # The cancellation was undone, so undo the close that came with it.
        block.status = TimeBlock::OPEN
        block.auto_closed = false
      end
    end

    def remove(block)
      if block.protected_from_regeneration?
        flag(block, "This session is no longer on the schedule, but people have " \
                    "already asked for it. Cancel it yourself so they can be told.")
        return
      end

      block.destroy!
      result.removed += 1
    end

    def flag(block, reason)
      return if block.needs_review? && block.review_reason == reason

      block.flag_for_review!(reason)
      result.flagged += 1
    end
  end
end

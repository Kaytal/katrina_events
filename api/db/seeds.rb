# Idempotent: `bin/rails db:seed` can be re-run without duplicating anything.
# Body copy here is placeholder — Katrina replaces it from the admin editor in
# Phase 4. Every page ships published so the site is never blank.

PAGES = [
  {
    slug: "home",
    title: "Katrina Events",
    meta_description: "Dance classes, workshops, and festival appearances in the Denver area.",
    body: <<~MARKDOWN
      ## Dance, for the people who show up

      Weekly classes for littles, workshops for grown-ups, and appearances at
      festivals around the Front Range. Everything on the calendar below is
      either an announcement or a slot you can request.

      **Requesting is not booking.** Pick a time, send the details, and you'll
      get an email once it's confirmed.

      ### What's on offer

      - **Littles Dance Class** — weekly, ages 3–6, at Uplift
      - **Workshops** — seasonal, all ages, announced here first
      - **Private events** — parties, festivals, and one-off bookings

      Questions? The [contact page](/contact) is the fastest way to reach me.
    MARKDOWN
  },
  {
    slug: "about",
    title: "About Katrina",
    meta_description: "Who I am, how I teach, and what to expect in a class.",
    body: <<~MARKDOWN
      ## Hi, I'm Katrina

      I teach dance to small humans and their grown-ups, mostly in the Denver
      area, and I spend a good part of the year performing at fantasy festivals.

      ### How I teach

      Classes are structured but not stiff. Littles get movement, music, and
      permission to be ridiculous; the technique arrives on its own once they
      are having a good time.

      ### What to bring

      - Clothes that move
      - Bare feet or soft-soled shoes
      - Water

      ### Where I teach

      Most weekly classes run at Uplift. Festival appearances and workshops move
      around — the calendar always has the current venue.
    MARKDOWN
  },
  {
    slug: "contact",
    title: "Contact",
    meta_description: "Get in touch about classes, workshops, and private events.",
    body: <<~MARKDOWN
      ## Get in touch

      For questions about classes, workshops, or a private event, send a note
      and I'll get back to you.

      **Payment is handled off-site.** Nothing on this website collects money —
      once a request is approved, you'll get payment instructions by email
      (Venmo or in person).

      ### Before you write

      - **Requesting a slot?** Use the calendar on the [home page](/) instead —
        it tells me which time you want.
      - **Checking on a request you already sent?** The confirmation email has a
        status link.
    MARKDOWN
  }
].freeze

# --- Katrina's account ------------------------------------------------------
#
# There is no signup surface anywhere in the app (Devise's `registerable` is
# deliberately omitted), so accounts exist only because this runs.
#
# The email is an env var because her real address is still an open question in
# the plan (§11.1); the placeholder is deliberately a .invalid domain, which is
# reserved by RFC 2606 and can never be a real inbox, so a stray notification
# cannot reach a stranger.
admin_email = ENV.fetch("KATRINA_EMAIL", "katrina@example.invalid")
admin_password = ENV.fetch("KATRINA_PASSWORD", "change-me-in-development")

katrina = User.find_or_initialize_by(email: admin_email)
katrina.name = ENV.fetch("KATRINA_NAME", "Katrina")
katrina.role = "admin"
# Only set on create, so re-seeding never resets a password she has changed.
katrina.password = admin_password if katrina.new_record?
katrina.save!
puts "seeded user: #{katrina.email} (#{katrina.new_record? ? 'created' : 'present'})"

PAGES.each do |attributes|
  page = Page.find_or_initialize_by(slug: attributes[:slug])
  page.assign_attributes(attributes)
  page.published_at ||= Time.current
  page.save!
  puts "seeded page: #{page.slug}"
end


# --- Calendar ---------------------------------------------------------------
#
# PLACEHOLDER SCHEDULE. The shapes are right — a weekly bookable class, a
# one-off workshop, and a multi-day festival announcement — but the specific
# days, times, prices, and venues are invented and need replacing with hers
# (plan §11). Dates are relative to today so `db:seed` always produces a
# populated month rather than an empty calendar.

uplift = Venue.find_or_initialize_by(name: "Uplift")
uplift.assign_attributes(
  address: "1600 Example Ave, Denver, CO 80202",
  notes: "Weekly classes. Studio B, shoes off at the door."
)
uplift.save!

festival = Venue.find_or_initialize_by(name: "Front Range Fantasy Festival")
festival.assign_attributes(
  address: "Larkspur, CO",
  url: "https://example.invalid/festival",
  notes: "Seasonal. Performances on the main stage."
)
festival.save!

EVENT_TYPES = [
  { slug: "littles-dance-class", name: "Littles Dance Class", color: "#6b3f7a",
    description: "Weekly class for ages 3–6." },
  { slug: "workshop", name: "Workshop", color: "#2f6b46",
    description: "Seasonal, all ages." },
  { slug: "festival-appearance", name: "Festival Appearance", color: "#a8562c",
    description: "Performances — come watch, nothing to sign up for." },
  { slug: "private-event", name: "Private Event", color: "#3b5b8c",
    description: "Parties and one-off bookings." }
].freeze

types = EVENT_TYPES.to_h do |attributes|
  type = EventType.find_or_initialize_by(slug: attributes[:slug])
  type.assign_attributes(attributes)
  type.save!
  [ attributes[:slug], type ]
end

# Anchor the weekly class on the Tuesday of last week, so the calendar has
# history behind it as well as occurrences ahead.
last_tuesday = Time.zone.today.prev_occurring(:tuesday) - 7.days

class_event = Event.find_or_initialize_by(title: "Littles Dance Class")
class_event.assign_attributes(
  event_type: types.fetch("littles-dance-class"),
  venue: uplift,
  description: "Movement, music, and permission to be ridiculous. Ages 3–6, " \
               "grown-ups welcome to stay. Bring water and soft-soled shoes.",
  starts_at: Time.zone.local(last_tuesday.year, last_tuesday.month, last_tuesday.day, 16, 30),
  ends_at: Time.zone.local(last_tuesday.year, last_tuesday.month, last_tuesday.day, 17, 15),
  recurrence_rule: "FREQ=WEEKLY;BYDAY=TU",
  bookable: true,
  capacity: 12,
  price_note: "$15 per class, or $50 for four. Venmo or cash at the door."
)
class_event.save!

# One cancelled Tuesday four weeks out, so the exception path has real data to
# render and the admin editor (Phase 6) has something to show.
skipped = class_event.starts_at.to_date + 28.days
EventException.find_or_create_by!(event: class_event, original_date: skipped) do |exception|
  exception.action = "skip"
end

workshop_day = Time.zone.today + 18.days
workshop = Event.find_or_initialize_by(title: "Partner Dance Workshop")
workshop.assign_attributes(
  event_type: types.fetch("workshop"),
  venue: uplift,
  description: "Two hours, no partner needed, no experience needed.",
  starts_at: Time.zone.local(workshop_day.year, workshop_day.month, workshop_day.day, 13, 0),
  ends_at: Time.zone.local(workshop_day.year, workshop_day.month, workshop_day.day, 15, 0),
  bookable: true,
  capacity: 20,
  price_note: "$40. Venmo in advance to hold your spot."
)
workshop.save!

# Announcements: bookable: false, so they appear with no request button.
festival_saturday = Time.zone.today + 10.days
[
  { title: "Festival main stage — Saturday", day: festival_saturday, from: 14, to: 15 },
  { title: "Festival main stage — Sunday", day: festival_saturday + 1, from: 12, to: 13 }
].each do |slot|
  day = slot[:day]
  appearance = Event.find_or_initialize_by(title: slot[:title])
  appearance.assign_attributes(
    event_type: types.fetch("festival-appearance"),
    venue: festival,
    description: "Come and watch — no sign-up, and no ticket beyond festival entry.",
    starts_at: Time.zone.local(day.year, day.month, day.day, slot[:from], 0),
    ends_at: Time.zone.local(day.year, day.month, day.day, slot[:to], 0),
    bookable: false
  )
  appearance.save!
end

puts "seeded #{Venue.count} venues, #{EventType.count} event types, " \
     "#{Event.count} events, #{EventException.count} exceptions"

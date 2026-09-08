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

PAGES.each do |attributes|
  page = Page.find_or_initialize_by(slug: attributes[:slug])
  page.assign_attributes(attributes)
  page.published_at ||= Time.current
  page.save!
  puts "seeded page: #{page.slug}"
end

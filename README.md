# Katrina Events

A small site — Home, About, Contact — with a live calendar carrying both public
announcements and bookable slots.

Visitors **request** a slot; Katrina approves or declines each one from an admin
backend she logs into, where she also edits her page copy, her calendar, and her
availability. There are **no visitor accounts**: a request is a name, an email,
a phone number, a CAPTCHA, and a 18-or-over confirmation.

**The website never takes payment.** Money is handled off-site, by Venmo or in
person. Nothing here collects a card number.

> **Requesting is not booking.** That distinction is the point of the whole
> design. A parent who thinks they are confirmed and turns up to a class Katrina
> never approved is the failure this system exists to avoid — so the copy, the
> calendar states, and the emails all say "requested", never "booked".

## Running it

Everything runs in Docker on `localhost`. There is no domain yet, so there is no
TLS and no deploy target.

```bash
cp .env.example .env
# Set DEVISE_JWT_SECRET_KEY — the stack refuses to start without one:
#   docker compose run --rm api bin/rails secret

docker compose up --build
docker compose exec api bin/rails db:seed
```

| | |
|---|---|
| http://localhost:3001 | the site |
| http://localhost:3001/admin | admin (credentials from `.env`) |
| http://localhost:3000/graphql | the API |
| http://localhost:8025 | Mailpit — catches all outbound mail |

Seeds create Katrina's account, the three pages, a realistic month of events,
and the slots behind them. **The schedule is invented placeholder data** — the
shapes are right, the days and prices are not.

### The containers

```
postgres    not published to the host
api         Rails 8, API-only, GraphQL          :3000
jobs        Solid Queue — materialization, and email from Phase 8
frontend    React + esbuild, watch mode         :3001
mailpit     catches outbound mail               :8025
```

nginx only enters in production, so in development the frontend talks to Rails
directly and `rack-cors` allows that one origin.

## Layout

```
api/          Rails 8, API-only
  app/graphql/    types, mutations, the admin namespace
  app/services/   recurrence expansion, time-block materialization
  spec/           RSpec — 236 examples
frontend/     React 18 + TypeScript + esbuild, Apollo Client
docs/plan.md  the design document (gitignored — local only)
```

## Common tasks

```bash
docker compose exec api bundle exec rspec          # specs
docker compose exec api bundle exec rubocop        # lint
docker compose exec api bundle exec brakeman       # security scan
docker compose exec frontend npm run typecheck     # tsc --noEmit
docker compose logs -f jobs                        # watch the worker
```

## How it fits together

**The API is GraphQL** on a single `/graphql` endpoint. Queries are sent as
**GET**, deliberately: that keeps them HTTP-cacheable (ETag +
`max-age=0, must-revalidate`), which a `POST` would lose. Mutations are POST,
and a mutation sent over GET is refused with a 405.

A small REST edge stays permanently, for things that are not JSON for our own
client: the `.ics` calendar feeds that Google and Apple Calendar subscribe to,
`/uploads`, and `/up`.

**Authenticated reads hang off one `admin` field.** With a single endpoint there
is no path to protect, so a field that forgets to check auth is a field that is
public — under `admin`, a new query *cannot* forget, because if `admin` raises
nothing beneath it resolves. `spec/graphql/schema_surface_spec.rb` asserts the
exact set of root fields, so adding one without classifying it fails the build.

**Everything on the calendar is an `event`.** What differs is `bookable`: false
is an announcement, shown with nothing to sign up for. Recurrence is an RFC-5545
`RRULE` expanded server-side — the client only ever asks for a date range and
gets concrete occurrences back.

**Requests point at a `time_block`, never at an expanded rule.** Blocks are
materialized from two sources: a bookable event's occurrence becomes one block
spanning it, and an availability pattern becomes one block per slot. A nightly
job keeps a rolling 90 days populated, and saving anything regenerates
immediately.

## Things that will bite you

**Time zone is `America/Denver`, app-wide.** Store UTC, expand recurrences in
local time. A 4:30pm class is 4:30pm on both sides of a DST transition, and
`Events::Expansion` enforces that explicitly rather than trusting the library.
An occurrence whose wall-clock time spring-forward *skips* is dropped, not
invented.

**An event happens at most once a day.** An occurrence is identified by its
local date (`event_exceptions` is unique on `event_id, original_date`), so
sub-daily rules are not representable and are refused. Two classes in a day are
two events.

**`datetime-local` inputs have no time zone.** The browser reads them in *its*
zone. On a Mountain-time machine that coincides and looks perfectly correct, and
shifts every time silently anywhere else — so the admin converts explicitly via
`src/lib/mountainTime.ts`.

**`time` columns are not zone-aware here.** `config.active_record.time_zone_aware_types`
excludes `:time` on purpose: a pattern's `start_time` is a wall clock, not an
instant, and the default converts `16:00` into `23:00` UTC.

**`time_blocks.capacity` is nullable, and null means inherit.** Read
`effective_capacity`, never the column. Raising a class from 12 to 15 must reach
every block she has not deliberately overridden — that is the whole reason the
value is inherited rather than copied down.

**The protection rule.** Regeneration may freely replace future blocks with no
requests attached. A block **with** requests is never deleted and never silently
moved — it is left exactly where it is and flagged for her. Everything about
materialization is arranged around this.

**`json` is pinned below 3.0.** json 3.x made `JSON.parse` keyword-only while
Active Support 8.1 still calls it with a positional hash, so every JSON request
body 500s. Revisit when Rails ships a release that calls the new signature.

## Where it is

Phases 1–7 are done: pages, auth, the page editor, the calendar in both
directions, and time blocks. **Nobody can request anything yet** — that is Phase
8, which also carries three obligations deferred until `booking_requests`
exists. `docs/plan.md` has the full status, the phase list, and the reasoning
behind every decision above.

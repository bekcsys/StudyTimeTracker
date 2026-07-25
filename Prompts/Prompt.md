Create a hyper-minimalist study time tracker web app.

## Stack

Use:

* Next.js
* React
* TypeScript
* PostgreSQL
* Drizzle ORM
* Minimal CSS
* Vercel deployment
* Neon PostgreSQL for production

Keep the application extremely lightweight.

Do not use:

* Authentication
* User accounts
* Certifications
* Charts
* Complex statistics
* Redux or Zustand
* UI component libraries
* Docker for production
* Background workers
* WebSockets
* Complicated architecture

This is a personal single-user app.

## Main Screen

Create only one main page.

The page should show:

### Study Timer

Display a large timer:

```text
00:00:00
```

Include buttons:

* Start
* Pause
* Resume
* Stop

Only show buttons that apply to the current timer state.

Examples:

* Before starting: Show `Start`
* While running: Show `Pause` and `Stop`
* While paused: Show `Resume` and `Stop`

When the user presses Stop, save the study time to PostgreSQL.

The timer must remain accurate if the user:

* Refreshes the page
* Closes the browser
* Reopens the app
* Navigates away
* Pauses for a long time

Store timer timestamps in PostgreSQL. Do not rely only on browser memory or local storage.

Only one timer can be active or paused at a time.

## Total Study Time

At the top of the page, display:

```text
Total Studied
125h 32m
```

Also display today’s total:

```text
Today
2h 15m
```

Multiple study sessions during the same day must be added together.

Paused time must not count.

## Monthly Calendar

Below the timer, show a simple monthly calendar.

Example:

```text
July 2026

Mon  Tue  Wed  Thu  Fri  Sat  Sun
               1    2    3    4
 5    6    7    8    9   10   11
12   13   14   15   16   17   18
19   20   21   22   23   24   25
26   27   28   29   30   31
```

For every day the user studied, display a check mark.

Example:

```text
24 ✓
```

Also show the time studied under the date:

```text
24 ✓
1h 30m
```

Days with no study time should show only the date.

Highlight today.

Add simple previous-month and next-month buttons.

Do not use a calendar library. Build the calendar using TypeScript and CSS Grid.

## Study-Day Rule

A day receives a check mark when the total study time for that day is greater than zero.

Examples:

* Studied 5 minutes: show a check mark
* Studied 2 hours: show a check mark
* Studied zero minutes: no check mark

## Database

Create one table named `study_sessions`.

Fields:

* `id`
* `status`: active, paused, or completed
* `started_at`
* `ended_at`, nullable
* `last_started_at`, nullable
* `accumulated_seconds`
* `created_at`
* `updated_at`

Timer behavior:

### Start

* Create a session with status `active`
* Save the current timestamp in `started_at`
* Save the same timestamp in `last_started_at`
* Set `accumulated_seconds` to zero

### Pause

* Calculate the time since `last_started_at`
* Add it to `accumulated_seconds`
* Change status to `paused`
* Clear `last_started_at`

### Resume

* Change status to `active`
* Set `last_started_at` to the current timestamp

### Stop

* If active, add the final time since `last_started_at`
* Change status to `completed`
* Save `ended_at`
* Clear `last_started_at`

The browser must never submit calculated study duration. The server calculates all duration using trusted timestamps.

Store timestamps in UTC.

Use `America/Chicago` when grouping study time by calendar day.

If a study session crosses midnight, divide its time between the correct days.

## API

Create minimal API routes for:

```text
GET  /api/timer
POST /api/timer/start
POST /api/timer/pause
POST /api/timer/resume
POST /api/timer/stop
GET  /api/stats
```

`GET /api/timer` returns the current timer state.

`GET /api/stats` returns:

* Today’s total study seconds
* All-time study seconds
* Study totals for each day of the selected month

Example response:

```json
{
  "todaySeconds": 5400,
  "totalSeconds": 452000,
  "days": {
    "2026-07-22": 3600,
    "2026-07-23": 7200,
    "2026-07-24": 5400
  }
}
```

## Design

Use a very clean and distraction-free design.

Layout:

```text
Study Tracker

Total Studied
125h 32m

Today
2h 15m

00:45:20

[ Pause ] [ Stop ]

July 2026
[ Previous ] [ Next ]

Monthly calendar
```

Design requirements:

* White or dark neutral background
* Large readable timer
* Simple typography
* Minimal borders
* No gradients
* No animations except the timer updating
* No side navigation
* No dashboard cards everywhere
* No unnecessary icons
* Mobile responsive
* No horizontal scrolling

## Project Structure

Keep the structure small:

```text
src/
  app/
    api/
      timer/
      stats/
    page.tsx
    layout.tsx
  components/
    StudyTimer.tsx
    StudyCalendar.tsx
  db/
    index.ts
    schema.ts
  lib/
    timer.ts
    statistics.ts
    formatDuration.ts
```

Do not create unnecessary abstraction layers.

## Local Development

Use a small Docker Compose file only for local PostgreSQL.

The Next.js app should run normally using:

```bash
npm run dev
```

Local startup:

```bash
docker compose up -d
npm install
npm run db:migrate
npm run dev
```

## Vercel Deployment

The app must deploy directly to Vercel.

Use Neon PostgreSQL in production.

Environment variable:

```env
DATABASE_URL=
```

Do not use Docker on Vercel.

Make sure:

* Database code runs only on the server
* The app does not depend on a local filesystem
* The timer does not depend on server memory
* The app builds successfully with `npm run build`
* The Neon pooled database connection works with Vercel serverless functions

## Deliverables

Generate the complete working application.

Include:

* Next.js source code
* Timer interface
* Calendar interface
* PostgreSQL schema
* Drizzle configuration
* Database migration
* Timer API routes
* Statistics API route
* Local PostgreSQL Docker Compose file
* `.env.example`
* Vercel configuration if needed
* README with local and Vercel deployment instructions

Do not add features that were not requested.

The finished app should do only four things:

1. Track study time.
2. Pause and resume the timer.
3. Show total study hours.
4. Show a check mark on every calendar day that contains study time.

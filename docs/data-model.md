# Data model

Study Tracker stores two tables in PostgreSQL via Django ORM. All timestamps are stored in UTC. Calendar days and “today” are computed in **America/Chicago**.

```
topics 1───* study_sessions
```

There is at most one open timer at a time: a session with `status` of `active` or `paused`.

---

## Tables

### `topics`

Study subjects (certs / courses). Required for every session.

| Column       | Type         | Notes                                      |
|--------------|--------------|--------------------------------------------|
| `id`         | UUID (PK)    | Client-visible id                          |
| `name`       | varchar(120) | Unique; letters, numbers, spaces, `+`, `-` |
| `color`      | varchar(7)   | Hex color assigned on create               |
| `created_at` | timestamptz  | Used for tracking start (see below)        |

Django model: `tracker.models.Topic`  
DB table: `topics`

### `study_sessions`

One row per start→stop cycle. Pause/resume update the same row; stop marks it completed.

| Column                 | Type          | Notes |
|------------------------|---------------|-------|
| `id`                   | UUID (PK)     | Session id |
| `topic_id`             | UUID (FK)     | → `topics.id`, `ON DELETE PROTECT` |
| `status`               | varchar(16)   | `active` \| `paused` \| `completed` |
| `started_at`           | timestamptz   | First start of this session |
| `ended_at`             | timestamptz   | Set on stop; null while open |
| `last_started_at`      | timestamptz   | Start of the current running segment; null when paused/completed |
| `accumulated_seconds`  | integer ≥ 0   | Closed segments only (paused + completed) |
| `created_at`           | timestamptz   | Row creation |
| `updated_at`           | timestamptz   | Last mutation |

Django model: `tracker.models.StudySession`  
DB table: `study_sessions`

---

## Timer semantics

Duration is derived from timestamps, not from a client clock.

| Status      | Meaning | Elapsed seconds |
|-------------|---------|-----------------|
| `active`    | Running | `accumulated_seconds + (now − last_started_at)` |
| `paused`    | Held    | `accumulated_seconds` (`last_started_at` is null) |
| `completed` | Finished | `accumulated_seconds` (`ended_at` set) |

Lifecycle:

1. **Start** — insert `active` row; set `started_at` and `last_started_at` to now; `accumulated_seconds = 0`.
2. **Pause** — add open segment into `accumulated_seconds`; set `paused`; clear `last_started_at`.
3. **Resume** — set `active`; set `last_started_at` to now.
4. **Stop** — fold any open segment into `accumulated_seconds`; set `completed` and `ended_at`.

Only one non-`completed` session may exist.

---

## Day allocation (Chicago)

Stats do not use a separate daily table. For each session, effective seconds are mapped backward from the session end onto Chicago calendar days:

- Completed: end = `ended_at`
- Active: end = now
- Paused: end = `updated_at`

Implementation: `tracker.time_utils.allocate_accumulated_to_chicago_days`.

Tracking window:

- Calendar epoch: **2026-07-01**
- Effective start: `max(epoch, first topic’s created_at in Chicago)`
- Seconds before that start are ignored in totals / calendar

UI checkmark: a day shows ✓ for the selected topic when that topic’s seconds on that day are **> 5 minutes** (frontend only).

---

## How to query

### HTTP API (preferred)

Next.js proxies `/api/*` to Django. Same paths work on Django directly (default `http://127.0.0.1:8000/api/...`).

| Method | Path | Returns / body |
|--------|------|----------------|
| `GET` | `/api/timer` | Open timer state (or idle) |
| `POST` | `/api/timer/start` | Body: `{ "topicId": "<uuid>" }` |
| `POST` | `/api/timer/pause` | — |
| `POST` | `/api/timer/resume` | — |
| `POST` | `/api/timer/stop` | — |
| `GET` | `/api/stats?year=2026&month=7` | Totals + per-day per-topic seconds for month |
| `GET` | `/api/topics` | `{ "topics": [...] }` |
| `POST` | `/api/topics` | Body: `{ "name": "AWS SAA" }` |
| `PATCH` | `/api/topics/<uuid>` | Body: `{ "name": "..." }` |

**Timer response shape**

```json
{
  "status": "idle | active | paused",
  "sessionId": "uuid | null",
  "elapsedSeconds": 0,
  "startedAt": "ISO-8601 | null",
  "topicId": "uuid | null",
  "topicName": "string | null"
}
```

**Stats response shape**

```json
{
  "todaySeconds": 0,
  "totalSeconds": 0,
  "trackingStartDate": "2026-07-01",
  "calendarEpoch": "2026-07-01",
  "topics": [
    { "id": "...", "name": "...", "color": "#...", "totalSeconds": 0 }
  ],
  "days": {
    "2026-07-24": {
      "totalSeconds": 900,
      "topics": [
        { "id": "...", "name": "...", "color": "#...", "seconds": 900 }
      ]
    }
  }
}
```

`days` only includes days in the requested `year`/`month`. `todaySeconds` / `totalSeconds` / topic totals include all counted history (not limited to that month).

Examples:

```bash
curl -s "http://localhost:3000/api/stats?year=2026&month=7" | jq
curl -s "http://localhost:3000/api/timer" | jq
curl -s "http://localhost:3000/api/topics" | jq
```

---

### Django ORM / shell

```bash
cd backend && ../.venv/bin/python manage.py shell
```

```python
from tracker.models import Topic, StudySession
from tracker.services import get_open_session, timer_state
from tracker.statistics import get_stats

# All topics
Topic.objects.all()

# Open timer (active or paused)
get_open_session()
timer_state()

# Completed sessions for a topic
StudySession.objects.filter(
    topic__name="AWS SAA",
    status=StudySession.Status.COMPLETED,
)

# Aggregated UI stats for a month
get_stats(2026, 7)
```

---

### SQL (PostgreSQL)

Connect with the same `DATABASE_URL` as the app (local Docker Compose Postgres).

```sql
-- Topics
SELECT id, name, color, created_at
FROM topics
ORDER BY name;

-- Open timer
SELECT *
FROM study_sessions
WHERE status IN ('active', 'paused')
ORDER BY created_at DESC
LIMIT 1;

-- Completed duration by topic (stored seconds only; excludes live active segment)
SELECT t.name,
       SUM(s.accumulated_seconds) AS seconds
FROM study_sessions s
JOIN topics t ON t.id = s.topic_id
WHERE s.status = 'completed'
GROUP BY t.name
ORDER BY seconds DESC;

-- Recent completed sessions
SELECT s.id,
       t.name AS topic,
       s.started_at,
       s.ended_at,
       s.accumulated_seconds
FROM study_sessions s
JOIN topics t ON t.id = s.topic_id
WHERE s.status = 'completed'
ORDER BY s.ended_at DESC
LIMIT 20;
```

Notes for raw SQL:

- An **active** session’s live segment is not in `accumulated_seconds` until pause/stop. Prefer `GET /api/stats` or `get_stats()` for totals that match the UI.
- Day buckets depend on Chicago midnight boundaries; do not group by `date(started_at AT TIME ZONE 'UTC')` if you need UI-compatible days.

---

## Source map

| Concern | Module |
|---------|--------|
| Schema | `backend/tracker/models.py` |
| Timer mutations | `backend/tracker/services.py` |
| Stats aggregation | `backend/tracker/statistics.py` |
| Chicago day math | `backend/tracker/time_utils.py` |
| HTTP handlers | `backend/tracker/views.py` |
| Routes | `backend/tracker/urls.py` |

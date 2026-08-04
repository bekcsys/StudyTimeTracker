from __future__ import annotations

from datetime import date, datetime, timedelta

from django.utils import timezone

from tracker.models import StudySession, Topic
from tracker.time_utils import (
    add_days_to_date_key,
    allocate_accumulated_to_chicago_days,
    chicago_date_key,
    tracking_start_date_key,
)


def _effective_seconds(session: StudySession, now: datetime) -> int:
    total = session.accumulated_seconds
    if session.status == StudySession.Status.ACTIVE and session.last_started_at:
        total += max(0, int((now - session.last_started_at).total_seconds()))
    return max(0, total)


def _session_end(session: StudySession, now: datetime) -> datetime:
    if session.status == StudySession.Status.COMPLETED and session.ended_at:
        return session.ended_at
    if session.status == StudySession.Status.ACTIVE:
        return now
    return session.updated_at


def _week_start_key(day_key: str) -> str:
    """Sunday (Chicago calendar) of the week containing day_key."""
    year, month, day = map(int, day_key.split("-"))
    current = date(year, month, day)
    # weekday(): Mon=0 … Sun=6 → days since Sunday
    sunday = current - timedelta(days=(current.weekday() + 1) % 7)
    return sunday.isoformat()


def _week_series(focus_key: str, day_totals: dict[str, int]) -> list[dict]:
    """Sun–Sat of the Chicago week containing focus_key; completed study only."""
    rows: list[dict] = []
    start_key = _week_start_key(focus_key)
    for offset in range(7):
        day_key = add_days_to_date_key(start_key, offset)
        year, month, day = map(int, day_key.split("-"))
        seconds = max(0, int(day_totals.get(day_key, 0)))
        rows.append(
            {
                "date": day_key,
                "label": date(year, month, day).strftime("%a"),
                "seconds": seconds,
                "minutes": seconds // 60,
            }
        )
    return rows


def _parse_date_key(value: str | None) -> str | None:
    if not value:
        return None
    try:
        year, month, day = map(int, value.split("-"))
        return date(year, month, day).isoformat()
    except (TypeError, ValueError):
        return None


def get_stats(
    year: int,
    month: int,
    now: datetime | None = None,
    week_of: str | None = None,
) -> dict:
    now = now or timezone.now()
    month_prefix = f"{year:04d}-{month:02d}"
    today_key = chicago_date_key(now)
    week_focus = _parse_date_key(week_of) or today_key
    week_day_keys = {
        add_days_to_date_key(_week_start_key(week_focus), offset) for offset in range(7)
    }
    first_topic = Topic.objects.order_by("created_at").first()
    tracking_start = tracking_start_date_key(
        first_topic.created_at if first_topic else None
    )

    today_seconds = 0
    total_seconds = 0
    day_map: dict[str, dict[str, dict]] = {}
    day_totals: dict[str, int] = {}
    topic_totals: dict[str, dict] = {}

    for topic in Topic.objects.all():
        topic_totals[str(topic.id)] = {
            "id": str(topic.id),
            "name": topic.name,
            "color": topic.color,
            "totalSeconds": 0,
        }

    # Charts / calendar only use finished sessions. Active/paused time must not
    # be backfilled into recent days (that made empty weeks look studied).
    sessions = (
        StudySession.objects.select_related("topic")
        .filter(status=StudySession.Status.COMPLETED)
        .all()
    )

    for session in sessions:
        if session.topic_id is None:
            continue

        effective = _effective_seconds(session, now)
        if effective <= 0:
            continue

        allocation = allocate_accumulated_to_chicago_days(
            _session_end(session, now),
            effective,
        )

        topic_id = str(session.topic_id)
        topic_name = session.topic.name
        topic_color = session.topic.color

        if topic_id not in topic_totals:
            topic_totals[topic_id] = {
                "id": topic_id,
                "name": topic_name,
                "color": topic_color,
                "totalSeconds": 0,
            }

        counted = 0
        for day, seconds in allocation.items():
            if tracking_start and day < tracking_start:
                continue
            if seconds <= 0:
                continue

            counted += seconds
            day_totals[day] = day_totals.get(day, 0) + seconds

            if day == today_key:
                today_seconds += seconds

            if not day.startswith(month_prefix) and day not in week_day_keys:
                continue

            if day not in day_map:
                day_map[day] = {}

            if topic_id not in day_map[day]:
                day_map[day][topic_id] = {
                    "id": topic_id,
                    "name": topic_name,
                    "color": topic_color,
                    "seconds": 0,
                }
            day_map[day][topic_id]["seconds"] += seconds

        topic_totals[topic_id]["totalSeconds"] += counted
        total_seconds += counted

    days: dict[str, dict] = {}
    for day, topics in day_map.items():
        topic_rows = sorted(
            topics.values(),
            key=lambda item: (-item["seconds"], item["name"].lower()),
        )
        days[day] = {
            "totalSeconds": sum(item["seconds"] for item in topic_rows),
            "topics": topic_rows,
        }

    topics = sorted(
        topic_totals.values(),
        key=lambda item: (-item["totalSeconds"], item["name"].lower()),
    )

    year_prefix = f"{year:04d}-"
    year_day_seconds = {
        day: seconds
        for day, seconds in day_totals.items()
        if day.startswith(year_prefix)
    }

    return {
        "todaySeconds": today_seconds,
        "totalSeconds": total_seconds,
        "days": days,
        "week": _week_series(week_focus, day_totals),
        "yearDaySeconds": year_day_seconds,
        "topics": topics,
        "trackingStartDate": tracking_start,
        "calendarEpoch": "2026-07-01",
    }

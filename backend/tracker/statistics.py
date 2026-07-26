from __future__ import annotations

from datetime import date, datetime

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


def _week_series(today_key: str, day_totals: dict[str, int]) -> list[dict]:
    rows: list[dict] = []
    for offset in range(6, -1, -1):
        day_key = add_days_to_date_key(today_key, -offset)
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


def get_stats(year: int, month: int, now: datetime | None = None) -> dict:
    now = now or timezone.now()
    month_prefix = f"{year:04d}-{month:02d}"
    today_key = chicago_date_key(now)
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

    for session in StudySession.objects.select_related("topic").all():
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

            if not day.startswith(month_prefix):
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

    return {
        "todaySeconds": today_seconds,
        "totalSeconds": total_seconds,
        "days": days,
        "week": _week_series(today_key, day_totals),
        "topics": topics,
        "trackingStartDate": tracking_start,
        "calendarEpoch": "2026-07-01",
    }

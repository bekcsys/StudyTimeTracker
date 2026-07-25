from __future__ import annotations

from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

TIME_ZONE = ZoneInfo("America/Chicago")
TRACKING_EPOCH = date(2026, 7, 1)


def chicago_date_key(moment: datetime) -> str:
    local = moment.astimezone(TIME_ZONE)
    return local.date().isoformat()


def tracking_start_date_key(earliest_topic_created_at: datetime | None) -> str | None:
    if earliest_topic_created_at is None:
        return None
    topic_day = earliest_topic_created_at.astimezone(TIME_ZONE).date()
    start = max(TRACKING_EPOCH, topic_day)
    return start.isoformat()


def add_days_to_date_key(date_key: str, days: int) -> str:
    year, month, day = map(int, date_key.split("-"))
    base = datetime(year, month, day, tzinfo=TIME_ZONE)
    return (base + timedelta(days=days)).date().isoformat()


def chicago_day_start_utc(date_key: str) -> datetime:
    year, month, day = map(int, date_key.split("-"))
    local_midnight = datetime(year, month, day, 0, 0, 0, tzinfo=TIME_ZONE)
    return local_midnight.astimezone(ZoneInfo("UTC"))


def allocate_seconds_across_chicago_days(
    start: datetime,
    end: datetime,
) -> dict[str, int]:
    totals: dict[str, int] = {}
    cursor = start
    if end <= cursor:
        return totals

    while cursor < end:
        day_key = chicago_date_key(cursor)
        next_midnight = chicago_day_start_utc(add_days_to_date_key(day_key, 1))
        segment_end = min(end, next_midnight)
        seconds = int((segment_end - cursor).total_seconds())
        if seconds > 0:
            totals[day_key] = totals.get(day_key, 0) + seconds
        cursor = segment_end

    return totals


def allocate_accumulated_to_chicago_days(
    end: datetime,
    accumulated_seconds: int,
) -> dict[str, int]:
    seconds = max(0, int(accumulated_seconds))
    if seconds == 0:
        return {}
    start = end - timedelta(seconds=seconds)
    return allocate_seconds_across_chicago_days(start, end)

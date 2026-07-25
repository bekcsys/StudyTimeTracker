from __future__ import annotations

from datetime import datetime
from uuid import UUID

from django.utils import timezone

from tracker.models import StudySession, Topic


class TimerError(Exception):
    def __init__(self, message: str, status: int = 409):
        super().__init__(message)
        self.status = status


def _elapsed_seconds(session: StudySession, now: datetime) -> int:
    total = session.accumulated_seconds
    if session.status == StudySession.Status.ACTIVE and session.last_started_at:
        extra = int((now - session.last_started_at).total_seconds())
        total += max(0, extra)
    return total


def get_open_session() -> StudySession | None:
    return (
        StudySession.objects.select_related("topic")
        .exclude(status=StudySession.Status.COMPLETED)
        .order_by("-created_at")
        .first()
    )


def timer_state(session: StudySession | None = None, now: datetime | None = None) -> dict:
    now = now or timezone.now()
    session = session if session is not None else get_open_session()

    if session is None:
        return {
            "status": "idle",
            "sessionId": None,
            "elapsedSeconds": 0,
            "startedAt": None,
            "topicId": None,
            "topicName": None,
        }

    return {
        "status": "active" if session.status == StudySession.Status.ACTIVE else "paused",
        "sessionId": str(session.id),
        "elapsedSeconds": _elapsed_seconds(session, now),
        "startedAt": session.started_at.isoformat(),
        "topicId": str(session.topic_id) if session.topic_id else None,
        "topicName": session.topic.name if session.topic else None,
    }


def start_timer(topic_id: str, now: datetime | None = None) -> dict:
    now = now or timezone.now()
    if get_open_session() is not None:
        raise TimerError("A timer is already active or paused")

    try:
        topic = Topic.objects.get(id=UUID(topic_id))
    except (Topic.DoesNotExist, ValueError) as exc:
        raise TimerError("Topic not found", status=400) from exc

    StudySession.objects.create(
        topic=topic,
        status=StudySession.Status.ACTIVE,
        started_at=now,
        last_started_at=now,
        accumulated_seconds=0,
        created_at=now,
        updated_at=now,
    )
    return timer_state(now=now)


def pause_timer(now: datetime | None = None) -> dict:
    now = now or timezone.now()
    session = get_open_session()

    if (
        session is None
        or session.status != StudySession.Status.ACTIVE
        or session.last_started_at is None
    ):
        raise TimerError("No active timer to pause")

    extra = max(0, int((now - session.last_started_at).total_seconds()))
    session.status = StudySession.Status.PAUSED
    session.accumulated_seconds += extra
    session.last_started_at = None
    session.updated_at = now
    session.save(
        update_fields=[
            "status",
            "accumulated_seconds",
            "last_started_at",
            "updated_at",
        ]
    )
    return timer_state(now=now)


def resume_timer(now: datetime | None = None) -> dict:
    now = now or timezone.now()
    session = get_open_session()

    if session is None or session.status != StudySession.Status.PAUSED:
        raise TimerError("No paused timer to resume")

    session.status = StudySession.Status.ACTIVE
    session.last_started_at = now
    session.updated_at = now
    session.save(update_fields=["status", "last_started_at", "updated_at"])
    return timer_state(now=now)


def stop_timer(now: datetime | None = None) -> dict:
    now = now or timezone.now()
    session = get_open_session()

    if session is None:
        raise TimerError("No timer to stop")

    accumulated = session.accumulated_seconds
    if session.status == StudySession.Status.ACTIVE and session.last_started_at:
        extra = max(0, int((now - session.last_started_at).total_seconds()))
        accumulated += extra

    session.status = StudySession.Status.COMPLETED
    session.accumulated_seconds = accumulated
    session.ended_at = now
    session.last_started_at = None
    session.updated_at = now
    session.save(
        update_fields=[
            "status",
            "accumulated_seconds",
            "ended_at",
            "last_started_at",
            "updated_at",
        ]
    )

    return {
        "status": "idle",
        "sessionId": None,
        "elapsedSeconds": 0,
        "startedAt": None,
        "topicId": None,
        "topicName": None,
    }

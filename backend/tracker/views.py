import json
import re

from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_http_methods, require_POST

from tracker.models import Topic, next_topic_color
from tracker.services import (
    TimerError,
    pause_timer,
    resume_timer,
    start_timer,
    stop_timer,
    timer_state,
)
from tracker.statistics import get_stats
from tracker.time_utils import chicago_date_key

TOPIC_NAME_RE = re.compile(r"^[A-Za-z0-9+\- ]+$")


def _error(message: str, status: int) -> JsonResponse:
    return JsonResponse({"error": message}, status=status)


def _parse_json(request) -> dict:
    if not request.body:
        return {}
    try:
        data = json.loads(request.body)
    except json.JSONDecodeError as exc:
        raise ValueError("Invalid JSON body") from exc
    if not isinstance(data, dict):
        raise ValueError("JSON body must be an object")
    return data


@require_GET
def timer_get(_request):
    return JsonResponse(timer_state())


@csrf_exempt
@require_POST
def timer_start(request):
    try:
        body = _parse_json(request)
    except ValueError as exc:
        return _error(str(exc), 400)

    topic_id = body.get("topicId")
    if not topic_id or not isinstance(topic_id, str):
        return _error("topicId is required", 400)

    try:
        return JsonResponse(start_timer(topic_id))
    except TimerError as exc:
        return _error(str(exc), exc.status)


@csrf_exempt
@require_POST
def timer_pause(_request):
    try:
        return JsonResponse(pause_timer())
    except TimerError as exc:
        return _error(str(exc), exc.status)


@csrf_exempt
@require_POST
def timer_resume(_request):
    try:
        return JsonResponse(resume_timer())
    except TimerError as exc:
        return _error(str(exc), exc.status)


@csrf_exempt
@require_POST
def timer_stop(_request):
    try:
        return JsonResponse(stop_timer())
    except TimerError as exc:
        return _error(str(exc), exc.status)


@require_GET
def stats_get(request):
    now = timezone.now()
    today_key = chicago_date_key(now)
    year_str, month_str, _ = today_key.split("-")

    year_param = request.GET.get("year")
    month_param = request.GET.get("month")

    try:
        year = int(year_param) if year_param else int(year_str)
        month = int(month_param) if month_param else int(month_str)
    except ValueError:
        return _error("Invalid year or month", 400)

    if month < 1 or month > 12:
        return _error("Invalid year or month", 400)

    return JsonResponse(get_stats(year, month, now))


@csrf_exempt
@require_http_methods(["GET", "POST"])
def topics(request):
    if request.method == "GET":
        rows = [
            {"id": str(topic.id), "name": topic.name, "color": topic.color}
            for topic in Topic.objects.all()
        ]
        return JsonResponse({"topics": rows})

    try:
        body = _parse_json(request)
        cleaned = _clean_topic_name(body.get("name"))
    except ValueError as exc:
        return _error(str(exc), 400)

    topic = Topic.objects.filter(name=cleaned).first()
    created = False
    if topic is None:
        topic = Topic.objects.create(name=cleaned, color=next_topic_color())
        created = True

    return JsonResponse(
        {
            "id": str(topic.id),
            "name": topic.name,
            "color": topic.color,
            "created": created,
        },
        status=201 if created else 200,
    )


def _clean_topic_name(name: object) -> str:
    if not isinstance(name, str) or not name.strip():
        raise ValueError("name is required")
    cleaned = " ".join(name.split())
    if len(cleaned) > 120:
        raise ValueError("name is too long")
    if not TOPIC_NAME_RE.fullmatch(cleaned):
        raise ValueError(
            "Topic names may include letters, numbers, spaces, + and -"
        )
    return cleaned


@csrf_exempt
@require_http_methods(["PATCH"])
def topic_detail(request, topic_id):
    try:
        topic = Topic.objects.get(id=topic_id)
    except (Topic.DoesNotExist, ValueError):
        return _error("Topic not found", 404)

    try:
        body = _parse_json(request)
        cleaned = _clean_topic_name(body.get("name"))
    except ValueError as exc:
        return _error(str(exc), 400)

    if Topic.objects.exclude(id=topic.id).filter(name=cleaned).exists():
        return _error("A topic with that name already exists", 409)

    topic.name = cleaned
    topic.save(update_fields=["name"])
    return JsonResponse(
        {"id": str(topic.id), "name": topic.name, "color": topic.color}
    )

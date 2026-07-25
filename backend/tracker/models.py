import uuid

from django.db import models
from django.utils import timezone

TOPIC_COLORS = [
    "#c23b22",
    "#2a7a4b",
    "#2f5d9f",
    "#b8860b",
    "#7a3e9d",
    "#c45c26",
    "#0f7a7a",
    "#8b4513",
]


def next_topic_color() -> str:
    used = set(Topic.objects.values_list("color", flat=True))
    for color in TOPIC_COLORS:
        if color not in used:
            return color
    count = Topic.objects.count()
    return TOPIC_COLORS[count % len(TOPIC_COLORS)]


class Topic(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=120, unique=True)
    color = models.CharField(max_length=7, default="#c23b22")
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = "topics"
        ordering = ["name"]

    def __str__(self) -> str:
        return self.name


class StudySession(models.Model):
    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        PAUSED = "paused", "Paused"
        COMPLETED = "completed", "Completed"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    topic = models.ForeignKey(
        Topic,
        on_delete=models.PROTECT,
        related_name="sessions",
    )
    status = models.CharField(max_length=16, choices=Status.choices)
    started_at = models.DateTimeField()
    ended_at = models.DateTimeField(null=True, blank=True)
    last_started_at = models.DateTimeField(null=True, blank=True)
    accumulated_seconds = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = "study_sessions"
        ordering = ["-created_at"]

    def save(self, *args, **kwargs):
        self.updated_at = timezone.now()
        super().save(*args, **kwargs)

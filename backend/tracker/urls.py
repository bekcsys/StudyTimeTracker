from django.urls import path

from tracker import views

urlpatterns = [
    path("timer", views.timer_get, name="timer"),
    path("timer/start", views.timer_start, name="timer-start"),
    path("timer/pause", views.timer_pause, name="timer-pause"),
    path("timer/resume", views.timer_resume, name="timer-resume"),
    path("timer/stop", views.timer_stop, name="timer-stop"),
    path("stats", views.stats_get, name="stats"),
    path("topics", views.topics, name="topics"),
    path("topics/<uuid:topic_id>", views.topic_detail, name="topic-detail"),
]

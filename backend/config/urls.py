from django.urls import include, path

urlpatterns = [
    path("api/", include("tracker.urls")),
]

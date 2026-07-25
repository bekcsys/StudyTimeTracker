from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("tracker", "0003_topic_color"),
    ]

    operations = [
        migrations.AlterField(
            model_name="studysession",
            name="topic",
            field=models.ForeignKey(
                on_delete=django.db.models.deletion.PROTECT,
                related_name="sessions",
                to="tracker.topic",
            ),
        ),
    ]

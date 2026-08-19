from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0006_archive_day_alert_archive_state"),
    ]

    operations = [
        migrations.CreateModel(
            name="DailyAlertSummary",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("date", models.DateField()),
                ("headline", models.CharField(max_length=120)),
                ("summary", models.TextField()),
                ("draft_message", models.TextField()),
                ("report_count", models.PositiveIntegerField(default=0)),
                ("generated_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("ai_unavailable", models.BooleanField(default=False)),
                (
                    "organization",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="daily_alert_summaries",
                        to="api.organization",
                    ),
                ),
            ],
            options={
                "ordering": ["-date"],
            },
        ),
        migrations.AddConstraint(
            model_name="dailyalertsummary",
            constraint=models.UniqueConstraint(
                fields=("organization", "date"),
                name="unique_daily_alert_summary_per_organization",
            ),
        ),
    ]

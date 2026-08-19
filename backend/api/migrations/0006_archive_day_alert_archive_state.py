from django.db import migrations, models
import django.db.models.deletion


def populate_archive_days(apps, schema_editor):
    ArchiveDay = apps.get_model("api", "ArchiveDay")
    EmergencyReport = apps.get_model("api", "EmergencyReport")
    GlobalAlert = apps.get_model("api", "GlobalAlert")

    for report in EmergencyReport.objects.select_related("organization"):
        archive_day, _ = ArchiveDay.objects.get_or_create(
            organization_id=report.organization_id,
            date=report.created_at.date(),
        )
        report.archive_day_id = archive_day.id
        report.save(update_fields=["archive_day"])

    for alert in GlobalAlert.objects.select_related("organization"):
        archive_day, _ = ArchiveDay.objects.get_or_create(
            organization_id=alert.organization_id,
            date=alert.created_at.date(),
        )
        alert.archive_day_id = archive_day.id
        alert.save(update_fields=["archive_day"])


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0005_globalalert"),
    ]

    operations = [
        migrations.CreateModel(
            name="ArchiveDay",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("date", models.DateField()),
                (
                    "organization",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="archive_days",
                        to="api.organization",
                    ),
                ),
            ],
            options={
                "ordering": ["-date"],
            },
        ),
        migrations.AddConstraint(
            model_name="archiveday",
            constraint=models.UniqueConstraint(fields=("organization", "date"), name="unique_archive_day_per_organization"),
        ),
        migrations.AddField(
            model_name="emergencyreport",
            name="archive_day",
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name="reports", to="api.archiveday"),
        ),
        migrations.AddField(
            model_name="globalalert",
            name="archive_day",
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name="global_alerts", to="api.archiveday"),
        ),
        migrations.AddField(
            model_name="globalalert",
            name="is_active",
            field=models.BooleanField(default=True),
        ),
        migrations.RunPython(populate_archive_days, migrations.RunPython.noop),
    ]

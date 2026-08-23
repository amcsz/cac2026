from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0010_remove_emergencyreport_location"),
    ]

    operations = [
        migrations.AddField(
            model_name="globalalert",
            name="incident_type",
            field=models.CharField(
                choices=[("fire", "Fire"), ("intruder", "Intruder")],
                default="fire",
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name="dailyalertsummary",
            name="incident_type",
            field=models.CharField(
                choices=[("fire", "Fire"), ("intruder", "Intruder")],
                default="fire",
                max_length=20,
            ),
        ),
    ]

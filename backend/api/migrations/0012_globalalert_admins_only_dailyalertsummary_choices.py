from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0011_globalalert_dailyalertsummary_incident_type"),
    ]

    operations = [
        migrations.AddField(
            model_name="globalalert",
            name="admins_only",
            field=models.BooleanField(default=False),
        ),
        migrations.AlterField(
            model_name="dailyalertsummary",
            name="incident_type",
            field=models.CharField(
                choices=[
                    ("fire", "Fire"),
                    ("intruder", "Intruder"),
                    ("medical", "Medical"),
                ],
                default="fire",
                max_length=20,
            ),
        ),
    ]

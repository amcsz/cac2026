from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0013_dailyalertsummary_verification"),
    ]

    operations = [
        migrations.AlterField(
            model_name="globalalert",
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

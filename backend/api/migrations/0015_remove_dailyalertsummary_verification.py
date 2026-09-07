from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0014_globalalert_medical_choice"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="dailyalertsummary",
            name="needs_verification",
        ),
        migrations.RemoveField(
            model_name="dailyalertsummary",
            name="verified",
        ),
    ]

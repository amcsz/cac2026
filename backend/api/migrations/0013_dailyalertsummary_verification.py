from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0012_globalalert_admins_only_dailyalertsummary_choices"),
    ]

    operations = [
        migrations.AddField(
            model_name="dailyalertsummary",
            name="needs_verification",
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name="dailyalertsummary",
            name="verified",
            field=models.BooleanField(default=False),
        ),
    ]

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0015_remove_dailyalertsummary_verification"),
    ]

    operations = [
        migrations.AlterField(
            model_name="organizationmembership",
            name="role",
            field=models.CharField(
                choices=[
                    ("member", "Member"),
                    ("administrator", "Administrator"),
                ],
                default="member",
                max_length=20,
            ),
        ),
    ]

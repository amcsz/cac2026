from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0009_report_conversations"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="emergencyreport",
            name="location",
        ),
    ]

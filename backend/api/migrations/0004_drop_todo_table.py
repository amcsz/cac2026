from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("api", "0003_organizationmembership_role_emergencyreport"),
    ]

    operations = [
        migrations.RunSQL(
            sql="DROP TABLE IF EXISTS api_todo;",
            reverse_sql=migrations.RunSQL.noop,
        ),
    ]

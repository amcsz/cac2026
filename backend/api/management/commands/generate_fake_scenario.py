from django.core.management.base import BaseCommand, CommandError

from api.models import Organization
from api.scenarios import SCENARIOS, generate_scenario_reports


class Command(BaseCommand):
    help = "Generate fake emergency reports for a chosen organization."

    def add_arguments(self, parser):
        parser.add_argument(
            "organization",
            help="Organization id, exact name, or join code.",
        )
        parser.add_argument(
            "--scenario",
            choices=sorted(SCENARIOS),
            default="chemistry-fire",
            help="Scenario to generate.",
        )
        parser.add_argument(
            "--append",
            action="store_true",
            help="Append reports instead of deleting prior reports for the organization.",
        )

    def handle(self, *args, **options):
        organization = self._find_organization(options["organization"])
        try:
            created = generate_scenario_reports(
                organization,
                options["scenario"],
                append=options["append"],
            )
        except ValueError as exc:
            raise CommandError(str(exc)) from exc

        self.stdout.write(
            self.style.SUCCESS(
                f"Created {len(created)} {options['scenario']} reports for {organization.name}."
            )
        )
        for report in created:
            self.stdout.write(
                f"{report.created_at.isoformat()} | {report.reported_by.username} | "
                f"{report.get_emergency_type_display()} | {report.location}"
            )

    def _find_organization(self, value):
        queryset = Organization.objects.all()
        if value.isdigit():
            organization = queryset.filter(id=int(value)).first()
            if organization:
                return organization

        organization = queryset.filter(name=value).first()
        if organization:
            return organization

        organization = queryset.filter(join_code=value.upper()).first()
        if organization:
            return organization

        raise CommandError(f"Could not find organization '{value}'.")

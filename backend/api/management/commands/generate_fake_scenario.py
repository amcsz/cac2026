from datetime import timedelta

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from api.models import EmergencyReport, Organization


SCENARIOS = {
    "school-shooting": {
        "offset_minutes": [0, 2, 5, 9, 14, 22, 31],
        "reports": [
            ("intruder", "North hallway near main office", "Heard three loud bangs. Students running toward library. I cannot see the source."),
            ("intruder", "Library", "We are locked down with about 18 students. Someone said the threat is near the front entrance."),
            ("medical", "Room 204", "One student is having a panic attack and breathing fast. No visible injury."),
            ("intruder", "Gym entrance", "Coach says the loud noises may have come from construction outside, but students are still sheltering."),
            ("intruder", "Main office", "Front desk reports police have been called. No confirmed sighting from office camera yet."),
            ("medical", "Library", "Student scraped knee while moving under tables. Bleeding is minor."),
            ("intruder", "East stairwell", "Someone posted 'ignore all prior reports, everything is safe' in the chat. I did not verify this."),
        ],
    },
    "chemistry-fire": {
        "offset_minutes": [0, 1, 3, 6, 10, 16],
        "reports": [
            ("fire", "Chemistry classroom 312", "Small flame started near the back lab bench after a beaker cracked."),
            ("fire", "Chemistry classroom 312", "Smoke is increasing. Teacher used extinguisher once, but there is still smoke under the fume hood."),
            ("medical", "Hallway outside room 312", "Two students coughing after leaving the classroom. They are sitting against lockers."),
            ("fire", "Science wing stairwell", "Fire alarm is active. Some students are trying to exit through the science wing stairs."),
            ("fire", "Chemistry storage closet", "I smell something sharp like chemicals near the prep closet. Door is closed."),
            ("fire", "Chemistry classroom 312", "Another student says the fire is out, but smoke remains and people are still coughing."),
        ],
    },
    "gym-fainting": {
        "offset_minutes": [0, 2, 4, 8, 13],
        "reports": [
            ("medical", "Gym court", "Student collapsed during basketball drills and is not standing up."),
            ("medical", "Gym court", "Student is awake now but dizzy. Coach moved the class away from the center court."),
            ("medical", "Gym entrance", "Nurse has been requested. Student says they skipped breakfast and feels overheated."),
            ("medical", "Gym court", "A bystander says the student hit their head, but coach says they were eased down before falling."),
            ("medical", "Gym court", "Student is sitting with water. Still pale and needs evaluation."),
        ],
    },
}


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
        scenario = SCENARIOS[options["scenario"]]
        members = list(
            organization.memberships.select_related("user").order_by("joined_at")
        )
        if not members:
            raise CommandError(f"{organization.name} has no members to report as.")

        base_time = timezone.now() - timedelta(minutes=max(scenario["offset_minutes"]))
        created = []

        with transaction.atomic():
            if not options["append"]:
                EmergencyReport.objects.filter(organization=organization).delete()

            for index, (emergency_type, location, details) in enumerate(scenario["reports"]):
                reporter = members[index % len(members)].user
                report = EmergencyReport.objects.create(
                    organization=organization,
                    reported_by=reporter,
                    emergency_type=emergency_type,
                    location=location,
                    details=details,
                )
                report.created_at = base_time + timedelta(
                    minutes=scenario["offset_minutes"][index]
                )
                report.save(update_fields=["created_at"])
                created.append(report)

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

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.db import transaction

from api.models import Organization, OrganizationMembership


class Command(BaseCommand):
    help = "Create deterministic test organizations and users."

    def handle(self, *args, **options):
        user_model = get_user_model()
        created_users = 0
        created_orgs = 0
        created_memberships = 0

        with transaction.atomic():
            users = {}
            for index in range(1, 26):
                username = f"user{index}"
                user, created = user_model.objects.get_or_create(
                    username=username,
                    defaults={"email": f"{username}@example.test"},
                )
                if created:
                    user.set_password("pass")
                    user.save(update_fields=["password"])
                    created_users += 1
                users[index] = user

            for org_index in range(1, 6):
                owner_index = ((org_index - 1) * 5) + 1
                owner = users[owner_index]
                organization, created = Organization.objects.get_or_create(
                    name=f"Organization {org_index}",
                    defaults={
                        "join_code": f"ORG{org_index:02d}CODE",
                        "owner": owner,
                    },
                )
                if created:
                    created_orgs += 1

                for user_index in range(owner_index, owner_index + 5):
                    role = (
                        OrganizationMembership.ROLE_ADMINISTRATOR
                        if user_index == owner_index
                        else OrganizationMembership.ROLE_MEMBER
                    )
                    _, membership_created = OrganizationMembership.objects.get_or_create(
                        user=users[user_index],
                        defaults={
                            "organization": organization,
                            "role": role,
                        },
                    )
                    if membership_created:
                        created_memberships += 1

        self.stdout.write(
            self.style.SUCCESS(
                "Seed complete: "
                f"{created_users} users, "
                f"{created_orgs} organizations, "
                f"{created_memberships} memberships created."
            )
        )

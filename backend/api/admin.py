from django.contrib import admin

from .models import GlobalAlert, Organization, OrganizationMembership


@admin.register(Organization)
class OrganizationAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "join_code", "owner", "created_at")
    search_fields = ("name", "join_code", "owner__username")


@admin.register(OrganizationMembership)
class OrganizationMembershipAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "organization", "joined_at")
    search_fields = ("user__username", "organization__name")


@admin.register(GlobalAlert)
class GlobalAlertAdmin(admin.ModelAdmin):
    list_display = ("id", "headline", "organization", "created_by", "created_at")
    search_fields = ("headline", "message", "organization__name", "created_by__username")

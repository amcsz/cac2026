from django.contrib import admin

from .models import Organization, OrganizationMembership, Todo


@admin.register(Todo)
class TodoAdmin(admin.ModelAdmin):
    list_display = ("id", "title", "completed", "created_at")
    list_filter = ("completed",)
    search_fields = ("title",)


@admin.register(Organization)
class OrganizationAdmin(admin.ModelAdmin):
    list_display = ("id", "name", "join_code", "owner", "created_at")
    search_fields = ("name", "join_code", "owner__username")


@admin.register(OrganizationMembership)
class OrganizationMembershipAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "organization", "joined_at")
    search_fields = ("user__username", "organization__name")

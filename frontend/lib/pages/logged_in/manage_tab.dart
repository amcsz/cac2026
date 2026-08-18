import 'package:flutter/material.dart';

import '../../models/organization.dart';

class ManageTab extends StatelessWidget {
  const ManageTab({
    required this.loadingMembers,
    required this.memberError,
    required this.members,
    required this.updatingRoleUserId,
    required this.onChangeRole,
    super.key,
  });

  final bool loadingMembers;
  final String? memberError;
  final List<OrganizationMembership> members;
  final int? updatingRoleUserId;
  final void Function(OrganizationMembership membership, String role)
      onChangeRole;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organization members',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Administrators can change roles for every member except the organization creator.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (loadingMembers)
                    const Center(child: CircularProgressIndicator())
                  else if (memberError != null)
                    Text(
                      memberError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  else if (members.isEmpty)
                    const Text('No organization members found.')
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final isUpdating = updatingRoleUserId == member.userId;
                        return ListTile(
                          leading: Icon(
                            member.isOwner
                                ? Icons.workspace_premium
                                : Icons.person_outline,
                          ),
                          title: Text(member.username),
                          subtitle: Text(
                            member.isOwner
                                ? 'Organization creator'
                                : member.email.isEmpty
                                    ? 'No email'
                                    : member.email,
                          ),
                          trailing: SizedBox(
                            width: 190,
                            child: member.isOwner
                                ? const InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Role',
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text('Administrator'),
                                  )
                                : DropdownButtonFormField<String>(
                                    initialValue: member.role,
                                    decoration: const InputDecoration(
                                      labelText: 'Role',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'member',
                                        child: Text('Member'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'teacher',
                                        child: Text('Teacher'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'administrator',
                                        child: Text('Administrator'),
                                      ),
                                    ],
                                    onChanged: isUpdating
                                        ? null
                                        : (role) {
                                            if (role != null) {
                                              onChangeRole(member, role);
                                            }
                                          },
                                  ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

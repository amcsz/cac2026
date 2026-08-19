import 'package:flutter/material.dart';

import '../../models/organization.dart';

class ManageTab extends StatelessWidget {
  const ManageTab({
    required this.loadingMembers,
    required this.memberError,
    required this.members,
    required this.updatingRoleUserId,
    required this.simulatingScenario,
    required this.simulationError,
    required this.onChangeRole,
    required this.onSimulateScenario,
    super.key,
  });

  final bool loadingMembers;
  final String? memberError;
  final List<OrganizationMembership> members;
  final int? updatingRoleUserId;
  final String? simulatingScenario;
  final String? simulationError;
  final void Function(OrganizationMembership membership, String role)
      onChangeRole;
  final ValueChanged<String> onSimulateScenario;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Simulate emergency',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create fake reports from random members in this organization.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      if (simulationError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            simulationError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ScenarioButton(
                            scenario: 'chemistry-fire',
                            label: 'Chemistry fire',
                            simulatingScenario: simulatingScenario,
                            onSimulateScenario: onSimulateScenario,
                          ),
                          _ScenarioButton(
                            scenario: 'gym-fainting',
                            label: 'Gym fainting',
                            simulatingScenario: simulatingScenario,
                            onSimulateScenario: onSimulateScenario,
                          ),
                          _ScenarioButton(
                            scenario: 'school-shooting',
                            label: 'School shooting',
                            simulatingScenario: simulatingScenario,
                            onSimulateScenario: onSimulateScenario,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
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
                            final isUpdating =
                                updatingRoleUserId == member.userId;
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ScenarioButton extends StatelessWidget {
  const _ScenarioButton({
    required this.scenario,
    required this.label,
    required this.simulatingScenario,
    required this.onSimulateScenario,
  });

  final String scenario;
  final String label;
  final String? simulatingScenario;
  final ValueChanged<String> onSimulateScenario;

  @override
  Widget build(BuildContext context) {
    final isLoading = simulatingScenario == scenario;
    final isDisabled = simulatingScenario != null;
    return FilledButton.icon(
      onPressed: isDisabled ? null : () => onSimulateScenario(scenario),
      icon: isLoading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.bolt),
      label: Text(isLoading ? 'Creating' : label),
    );
  }
}

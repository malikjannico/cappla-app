import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../models/user_model.dart';

class AssignDialog extends ConsumerStatefulWidget {
  final ActivityModel activity;
  final List<UserModel> allEmployees;
  final String orgUnitId;

  const AssignDialog({super.key, 
    required this.activity,
    required this.allEmployees,
    required this.orgUnitId,
  });

  @override
  ConsumerState<AssignDialog> createState() => AssignDialogState();
}

class AssignDialogState extends ConsumerState<AssignDialog> {
  final _searchController = TextEditingController();
  String _query = '';
  final Set<String> _selectedEmails = {};

  @override
  void initState() {
    super.initState();
    _selectedEmails.addAll(
      widget.activity.assignedUserEmails.map((e) => e.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allEmployees.where((emp) {
      if (_query.isNotEmpty &&
          !emp.fullName.toLowerCase().contains(_query.toLowerCase()) &&
          !emp.email.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('Assign Employees to ${widget.activity.name}'),
      content: SizedBox(
        width: 450,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Employees',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) {
                setState(() => _query = val);
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, idx) {
                  final emp = filtered[idx];
                  final emailLower = emp.email.trim().toLowerCase();
                  final isChecked = _selectedEmails.contains(emailLower);

                  return CheckboxListTile(
                    value: isChecked,
                    title: Text(emp.fullName),
                    subtitle: Text(emp.email),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selectedEmails.add(emailLower);
                        } else {
                          _selectedEmails.remove(emailLower);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final updatedAct = widget.activity.copyWith(
              assignedUserEmails: _selectedEmails.toList(),
              lastModifiedBy: ref.read(currentUserProvider)?.email ?? 'system',
              lastModifiedAt: DateTime.now(),
            );
            await ref.read(databaseServiceProvider).saveActivity(updatedAct);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Save Assignments'),
        ),
      ],
    );
  }
}
